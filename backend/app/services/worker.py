import asyncio
import logging

from pydantic import ValidationError

from app.integrations.queue import JobQueue, ReceivedQueueMessage
from app.schemas.queue import QueueJob
from app.tasks.base import PermanentTaskError, TaskHandler
from app.tasks.registry import TaskRegistry

logger = logging.getLogger(__name__)


class QueueWorker:
    def __init__(
        self,
        queue: JobQueue,
        registry: TaskRegistry,
        *,
        poll_interval_seconds: float,
        visibility_timeout_seconds: int,
        max_attempts: int,
        retry_base_seconds: int,
        retry_max_seconds: int,
        batch_size: int,
    ) -> None:
        self._queue = queue
        self._registry = registry
        self._poll_interval_seconds = poll_interval_seconds
        self._visibility_timeout_seconds = visibility_timeout_seconds
        self._max_attempts = max_attempts
        self._retry_base_seconds = retry_base_seconds
        self._retry_max_seconds = retry_max_seconds
        self._batch_size = batch_size

    async def run(self, stop_event: asyncio.Event) -> None:
        logger.info("Queue worker started")
        while not stop_event.is_set():
            try:
                processed = await self.run_once()
            except Exception:
                logger.exception("Queue polling failed")
                processed = 0

            if processed == 0:
                try:
                    await asyncio.wait_for(
                        stop_event.wait(),
                        timeout=self._poll_interval_seconds,
                    )
                except TimeoutError:
                    pass
        logger.info("Queue worker stopped")

    async def run_once(self) -> int:
        messages = await self._queue.read(
            visibility_timeout_seconds=self._visibility_timeout_seconds,
            quantity=self._batch_size,
        )
        if not messages:
            return 0

        await asyncio.gather(*(self._process(message) for message in messages))
        return len(messages)

    async def _process(self, received: ReceivedQueueMessage) -> None:
        try:
            job = QueueJob.model_validate(received.message)
        except ValidationError as exc:
            trace_id = (
                received.message.get("trace_id", "-") if isinstance(received.message, dict) else "-"
            )
            logger.error(
                "Archiving malformed queue message message_id=%s trace_id=%s "
                "failure_code=INVALID_MESSAGE error=%s",
                received.message_id,
                trace_id,
                exc.errors(include_url=False),
            )
            await self._archive(received.message_id)
            return

        attempt = job.attempt + received.read_count
        handler = self._registry.get(job.job_type)
        if handler is None:
            logger.error(
                "Archiving queue message without handler message_id=%s "
                "job_type=%s resource_id=%s trace_id=%s "
                "failure_code=HANDLER_NOT_REGISTERED",
                received.message_id,
                job.job_type,
                job.resource_id,
                job.trace_id,
            )
            await self._archive(received.message_id)
            return

        try:
            await self._run_with_heartbeat(received.message_id, handler, job)
        except PermanentTaskError as exc:
            logger.error(
                "Task permanently failed message_id=%s job_type=%s resource_id=%s "
                "trace_id=%s attempt=%s failure_code=%s",
                received.message_id,
                job.job_type,
                job.resource_id,
                job.trace_id,
                attempt,
                exc.failure_code,
            )
            await self._archive(received.message_id)
        except Exception:
            if attempt >= self._max_attempts:
                logger.exception(
                    "Task exhausted retries message_id=%s job_type=%s resource_id=%s "
                    "trace_id=%s attempt=%s failure_code=MAX_ATTEMPTS_EXCEEDED",
                    received.message_id,
                    job.job_type,
                    job.resource_id,
                    job.trace_id,
                    attempt,
                )
                on_exhausted = getattr(handler, "on_exhausted", None)
                if on_exhausted is not None:
                    try:
                        await asyncio.wait_for(
                            on_exhausted(job),
                            timeout=max(float(self._visibility_timeout_seconds), 0.01),
                        )
                    except Exception:
                        logger.exception(
                            "Task exhaustion callback failed message_id=%s job_type=%s "
                            "resource_id=%s trace_id=%s",
                            received.message_id,
                            job.job_type,
                            job.resource_id,
                            job.trace_id,
                        )
                        try:
                            await self._queue.set_visibility_timeout(
                                received.message_id,
                                visibility_timeout_seconds=self._retry_max_seconds,
                            )
                        except Exception:
                            logger.exception(
                                "Task exhaustion callback retry scheduling failed "
                                "message_id=%s job_type=%s resource_id=%s trace_id=%s",
                                received.message_id,
                                job.job_type,
                                job.resource_id,
                                job.trace_id,
                            )
                        return
                await self._archive(received.message_id)
                return

            retry_delay = min(
                self._retry_base_seconds * (2 ** max(attempt - 1, 0)),
                self._retry_max_seconds,
            )
            logger.exception(
                "Task will retry message_id=%s job_type=%s resource_id=%s "
                "trace_id=%s attempt=%s retry_delay_seconds=%s "
                "failure_code=RETRYABLE_ERROR",
                received.message_id,
                job.job_type,
                job.resource_id,
                job.trace_id,
                attempt,
                retry_delay,
            )
            await self._queue.set_visibility_timeout(
                received.message_id,
                visibility_timeout_seconds=retry_delay,
            )
        else:
            logger.info(
                "Task completed message_id=%s job_type=%s resource_id=%s trace_id=%s attempt=%s",
                received.message_id,
                job.job_type,
                job.resource_id,
                job.trace_id,
                attempt,
            )
            await self._archive(received.message_id)

    async def _run_with_heartbeat(
        self,
        message_id: int,
        handler: TaskHandler,
        job: QueueJob,
    ) -> None:
        task = asyncio.create_task(handler(job))
        heartbeat_seconds = max(self._visibility_timeout_seconds / 2, 0.01)

        while True:
            try:
                await asyncio.wait_for(
                    asyncio.shield(task),
                    timeout=heartbeat_seconds,
                )
                return
            except TimeoutError:
                try:
                    renewed = await self._queue.set_visibility_timeout(
                        message_id,
                        visibility_timeout_seconds=self._visibility_timeout_seconds,
                    )
                except Exception:
                    logger.exception(
                        "Queue visibility renewal errored message_id=%s",
                        message_id,
                    )
                    continue
                if not renewed:
                    logger.warning(
                        "Queue visibility renewal failed message_id=%s",
                        message_id,
                    )

    async def _archive(self, message_id: int) -> None:
        archived = await self._queue.archive(message_id)
        if not archived:
            logger.warning("Queue archive returned false message_id=%s", message_id)
