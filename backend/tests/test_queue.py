import asyncio
from datetime import UTC, datetime
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.integrations.queue import ReceivedQueueMessage
from app.schemas.queue import JobType, QueueJob
from app.services.worker import QueueWorker
from app.tasks.base import PermanentTaskError
from app.tasks.registry import TaskRegistry


class FakeQueue:
    def __init__(self, messages: list[ReceivedQueueMessage] | None = None) -> None:
        self.messages = messages or []
        self.archived: list[int] = []
        self.visibility_updates: list[tuple[int, int]] = []
        self.enqueued: list[QueueJob] = []

    async def enqueue(
        self,
        job: QueueJob,
        *,
        delay_seconds: int = 0,
        session=None,
    ) -> int:
        self.enqueued.append(job)
        return len(self.enqueued)

    async def read(
        self,
        *,
        visibility_timeout_seconds: int,
        quantity: int,
    ) -> list[ReceivedQueueMessage]:
        messages = self.messages[:quantity]
        self.messages = self.messages[quantity:]
        return messages

    async def archive(self, message_id: int) -> bool:
        self.archived.append(message_id)
        return True

    async def set_visibility_timeout(
        self,
        message_id: int,
        *,
        visibility_timeout_seconds: int,
    ) -> bool:
        self.visibility_updates.append((message_id, visibility_timeout_seconds))
        return True


class RecordingHandler:
    def __init__(
        self,
        *,
        error: Exception | None = None,
        wait_seconds: float = 0,
    ) -> None:
        self.error = error
        self.wait_seconds = wait_seconds
        self.jobs: list[QueueJob] = []
        self.exhausted_jobs: list[QueueJob] = []

    async def __call__(self, job: QueueJob) -> None:
        self.jobs.append(job)
        if self.wait_seconds:
            await asyncio.sleep(self.wait_seconds)
        if self.error:
            raise self.error

    async def on_exhausted(self, job: QueueJob) -> None:
        self.exhausted_jobs.append(job)


def make_job(**overrides: object) -> QueueJob:
    values = {
        "job_type": JobType.DIAGNOSIS_RUN,
        "resource_id": uuid4(),
        "attempt": 0,
        "trace_id": "req_queue_test_123",
    }
    values.update(overrides)
    return QueueJob.model_validate(values)


def make_message(
    message: object | None = None,
    *,
    message_id: int = 1,
    read_count: int = 1,
) -> ReceivedQueueMessage:
    now = datetime.now(UTC)
    return ReceivedQueueMessage(
        message_id=message_id,
        read_count=read_count,
        enqueued_at=now,
        visible_at=now,
        message=message if message is not None else make_job().model_dump(mode="json"),
    )


def make_worker(
    queue: FakeQueue,
    registry: TaskRegistry,
    *,
    visibility_timeout_seconds: int = 60,
    max_attempts: int = 3,
) -> QueueWorker:
    return QueueWorker(
        queue,
        registry,
        poll_interval_seconds=0.01,
        visibility_timeout_seconds=visibility_timeout_seconds,
        max_attempts=max_attempts,
        retry_base_seconds=5,
        retry_max_seconds=60,
        batch_size=5,
    )


def test_queue_job_contract_rejects_unknown_or_extra_fields() -> None:
    with pytest.raises(ValidationError):
        make_job(job_type="UNKNOWN")
    with pytest.raises(ValidationError):
        make_job(secret="must-not-enter-queue")


async def test_successful_task_is_archived() -> None:
    message = make_message()
    queue = FakeQueue([message])
    handler = RecordingHandler()
    registry = TaskRegistry()
    registry.register(JobType.DIAGNOSIS_RUN, handler)

    processed = await make_worker(queue, registry).run_once()

    assert processed == 1
    assert len(handler.jobs) == 1
    assert queue.archived == [message.message_id]
    assert queue.visibility_updates == []


async def test_transient_failure_gets_exponential_retry_visibility() -> None:
    message = make_message(read_count=2)
    queue = FakeQueue([message])
    registry = TaskRegistry()
    registry.register(JobType.DIAGNOSIS_RUN, RecordingHandler(error=RuntimeError("temporary")))

    await make_worker(queue, registry).run_once()

    assert queue.archived == []
    assert queue.visibility_updates == [(message.message_id, 10)]


async def test_max_attempt_failure_is_archived() -> None:
    message = make_message(read_count=3)
    queue = FakeQueue([message])
    registry = TaskRegistry()
    handler = RecordingHandler(error=RuntimeError("still failing"))
    registry.register(JobType.DIAGNOSIS_RUN, handler)

    await make_worker(queue, registry).run_once()

    assert queue.archived == [message.message_id]
    assert queue.visibility_updates == []
    assert len(handler.exhausted_jobs) == 1
    assert handler.exhausted_jobs[0].resource_id == handler.jobs[0].resource_id


async def test_permanent_failure_is_archived_without_retry() -> None:
    message = make_message()
    queue = FakeQueue([message])
    registry = TaskRegistry()
    registry.register(
        JobType.DIAGNOSIS_RUN,
        RecordingHandler(error=PermanentTaskError("INVALID_STATE", "invalid")),
    )

    await make_worker(queue, registry).run_once()

    assert queue.archived == [message.message_id]
    assert queue.visibility_updates == []


@pytest.mark.parametrize(
    "message",
    [
        {"job_type": "DIAGNOSIS_RUN"},
        ["not", "an", "object"],
        "invalid",
    ],
)
async def test_malformed_message_is_archived(message: object) -> None:
    received = make_message(message)
    queue = FakeQueue([received])

    await make_worker(queue, TaskRegistry()).run_once()

    assert queue.archived == [received.message_id]


async def test_unregistered_handler_message_is_archived() -> None:
    message = make_message()
    queue = FakeQueue([message])

    await make_worker(queue, TaskRegistry()).run_once()

    assert queue.archived == [message.message_id]


async def test_long_task_renews_visibility_until_completion() -> None:
    message = make_message()
    queue = FakeQueue([message])
    handler = RecordingHandler(wait_seconds=0.04)
    registry = TaskRegistry()
    registry.register(JobType.DIAGNOSIS_RUN, handler)

    await make_worker(
        queue,
        registry,
        visibility_timeout_seconds=0.02,
    ).run_once()

    assert queue.archived == [message.message_id]
    assert len(queue.visibility_updates) >= 1
    assert all(update == (message.message_id, 0.02) for update in queue.visibility_updates)


async def test_idle_worker_stops_without_polling_forever() -> None:
    queue = FakeQueue()
    worker = make_worker(queue, TaskRegistry())
    stop_event = asyncio.Event()

    task = asyncio.create_task(worker.run(stop_event))
    await asyncio.sleep(0.02)
    stop_event.set()
    await asyncio.wait_for(task, timeout=1)
