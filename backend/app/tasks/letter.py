import asyncio
import math
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from typing import Protocol
from uuid import UUID, uuid4

from pydantic import ValidationError
from sqlalchemy import select

from app.db.session import Database
from app.integrations.openai_letter import (
    LetterCompletion,
    LetterInput,
    LetterPermanentError,
    OpenAILetterProvider,
)
from app.integrations.queue import JobQueue
from app.models.letter import Letter
from app.models.notification import Notification
from app.models.plant import Plant, PlantDiary, SpeciesCareGuide
from app.schemas.queue import JobType, QueueJob
from app.services.letter import lock_active_plant
from app.tasks.base import PermanentTaskError


class LetterSensorSummary(Protocol):
    async def read(self, plant_id: UUID, diary_date: date) -> str: ...


class UnconfiguredLetterSensorSummary:
    async def read(self, plant_id: UUID, diary_date: date) -> str:
        raise LetterPermanentError("LETTER_SENSOR_NOT_CONFIGURED")


@dataclass(frozen=True)
class LetterWork:
    token: UUID
    user_id: UUID
    plant_id: UUID
    diary_date: date
    context: dict
    snapshot: dict | None


class SQLAlchemyLetterRepository:
    def __init__(
        self,
        database: Database,
        queue: JobQueue,
        *,
        lease_seconds: int = 120,
        max_attempts: int = 5,
    ) -> None:
        self._database = database
        self._queue = queue
        self._lease_seconds = lease_seconds
        self._max_attempts = max_attempts

    async def _lock(self, session, letter_id: UUID):
        row = (
            await session.execute(
                select(Plant.user_id, Plant.id)
                .join(Letter, Letter.plant_id == Plant.id)
                .where(Letter.id == letter_id)
            )
        ).one_or_none()
        if row is None:
            return None
        plant = await lock_active_plant(session, row.user_id, row.id)
        if plant is None:
            return None
        letter = await session.scalar(
            select(Letter)
            .where(Letter.id == letter_id, Letter.deleted_at.is_(None))
            .with_for_update()
        )
        return (letter, plant) if letter else None

    async def _enqueue(self, session, letter_id, job_type, delay=0):
        await self._queue.enqueue(
            QueueJob(job_type=job_type, resource_id=letter_id, trace_id=f"letter:{letter_id}"),
            delay_seconds=max(0, math.ceil(delay)),
            session=session,
        )

    async def start(self, letter_id: UUID) -> LetterWork | None:
        async with self._database.session_context() as session:
            row = await self._lock(session, letter_id)
            if row is None:
                return None
            letter, plant = row
            if letter.status in ("COMPLETED", "FAILED"):
                return None
            now = datetime.now(UTC)
            if letter.status == "PROCESSING" and letter.lease_until and letter.lease_until > now:
                # Do not archive the only recovery opportunity while a crashed worker's lease lives.
                await self._enqueue(
                    session,
                    letter.id,
                    JobType.LETTER_GENERATION_RUN,
                    (letter.lease_until - now).total_seconds(),
                )
                return None
            if letter.attempt_count >= self._max_attempts:
                letter.status = "FAILED"
                letter.failure_code = "LETTER_RETRY_EXHAUSTED"
                letter.lease_token = letter.lease_until = None
                return None
            diary = await session.get(PlantDiary, letter.diary_id)
            guide = await session.get(SpeciesCareGuide, plant.species_reference_id)
            if diary is None or guide is None:
                letter.status = "FAILED"
                letter.failure_code = "LETTER_SOURCE_NOT_FOUND"
                return None
            letter.status = "PROCESSING"
            letter.started_at = now
            letter.lease_token = uuid4()
            letter.lease_until = now + timedelta(seconds=self._lease_seconds)
            letter.attempt_count += 1
            context = dict(
                plant_nickname=plant.nickname,
                species_name=guide.display_name,
                personality=plant.personality_type,
                diary_date=diary.diary_date,
                diary_content=diary.content,
            )
            # #42 owns these fields; absence does not create fictitious data.
            for field, source in (("diary_title", "title"), ("weather_summary", "weather")):
                value = getattr(diary, source, None)
                if value:
                    context[field] = str(value)
            return LetterWork(
                letter.lease_token,
                plant.user_id,
                plant.id,
                diary.diary_date,
                context,
                letter.input_snapshot,
            )

    async def save_snapshot(self, letter_id: UUID, token: UUID, snapshot: LetterInput) -> bool:
        async with self._database.session_context() as session:
            row = await self._lock(session, letter_id)
            if row is None or not self._owns(row[0], token):
                return False
            if row[0].input_snapshot is None:
                row[0].input_snapshot = snapshot.model_dump(mode="json")
            return True

    @staticmethod
    def _owns(letter, token) -> bool:
        return letter.status == "PROCESSING" and letter.lease_token == token

    async def complete(self, letter_id: UUID, token: UUID, result: LetterCompletion) -> None:
        async with self._database.session_context() as session:
            row = await self._lock(session, letter_id)
            if row is None or not self._owns(row[0], token):
                return
            letter = row[0]
            now = datetime.now(UTC)
            letter.status = "COMPLETED"
            letter.content = result.content
            letter.generated_at = now
            letter.provider = "OPENAI"
            letter.model = result.model_name
            letter.provider_response_id = result.response_id
            letter.input_tokens = result.input_tokens
            letter.output_tokens = result.output_tokens
            letter.failure_code = None
            letter.lease_token = letter.lease_until = None
            await self._enqueue(
                session,
                letter.id,
                JobType.LETTER_PUBLISH,
                (letter.scheduled_at - now).total_seconds(),
            )

    async def fail(self, letter_id: UUID, token: UUID, code: str, *, retry: bool) -> None:
        async with self._database.session_context() as session:
            row = await self._lock(session, letter_id)
            if row is None or not self._owns(row[0], token):
                return
            letter = row[0]
            letter.status = (
                "PENDING" if retry and letter.attempt_count < self._max_attempts else "FAILED"
            )
            letter.failure_code = code
            letter.lease_token = letter.lease_until = None

    async def exhausted(self, letter_id: UUID) -> None:
        async with self._database.session_context() as session:
            row = await self._lock(session, letter_id)
            if row is None:
                return
            letter = row[0]
            if letter.status == "PROCESSING" and letter.lease_until > datetime.now(UTC):
                await self._enqueue(
                    session,
                    letter.id,
                    JobType.LETTER_GENERATION_RUN,
                    (letter.lease_until - datetime.now(UTC)).total_seconds(),
                )
                return
            if letter.status in ("PENDING", "PROCESSING"):
                letter.status = "FAILED"
                letter.failure_code = letter.failure_code or "LETTER_RETRY_EXHAUSTED"
                letter.lease_token = letter.lease_until = None

    async def publish(self, letter_id: UUID) -> None:
        async with self._database.session_context() as session:
            row = await self._lock(session, letter_id)
            if row is None:
                return
            letter, plant = row
            if letter.status != "COMPLETED" or letter.published_at is not None:
                return
            now = datetime.now(UTC)
            if letter.scheduled_at > now:
                await self._enqueue(
                    session,
                    letter.id,
                    JobType.LETTER_PUBLISH,
                    (letter.scheduled_at - now).total_seconds(),
                )
                return
            letter.published_at = now
            notification = Notification(
                id=uuid4(),
                user_id=plant.user_id,
                plant_id=plant.id,
                type="LETTER_ARRIVED",
                title=f"{plant.nickname}의 편지가 도착했어요",
                body=letter_notification_body(plant.personality_type),
                source_type="LETTER",
                source_id=letter.id,
            )
            session.add(notification)
            await self._enqueue(session, notification.id, JobType.PUSH_NOTIFICATION_SEND)


class LetterGenerationHandler:
    def __init__(
        self,
        repository: SQLAlchemyLetterRepository,
        provider: OpenAILetterProvider,
        sensors: LetterSensorSummary,
        *,
        timeout_seconds: float = 60,
    ) -> None:
        self._repository = repository
        self._provider = provider
        self._sensors = sensors
        self._timeout = timeout_seconds

    async def __call__(self, job: QueueJob) -> None:
        work = await self._repository.start(job.resource_id)
        if work is None:
            return
        try:
            async with asyncio.timeout(self._timeout):
                if work.snapshot is not None:
                    snapshot = LetterInput.model_validate(work.snapshot)
                else:
                    summary = await self._sensors.read(work.plant_id, work.diary_date)
                    snapshot = LetterInput(**work.context, sensor_summary=summary)
                    if not await self._repository.save_snapshot(
                        job.resource_id, work.token, snapshot
                    ):
                        return
                result = await self._provider.generate(snapshot, safety_user_id=str(work.user_id))
            if not result.content.strip():
                raise LetterPermanentError("LETTER_PROVIDER_EMPTY_RESPONSE")
            await self._repository.complete(job.resource_id, work.token, result)
        except (LetterPermanentError, ValidationError) as exc:
            code = (
                exc.failure_code
                if isinstance(exc, LetterPermanentError)
                else "LETTER_INVALID_INPUT"
            )
            await self._repository.fail(job.resource_id, work.token, code, retry=False)
            raise PermanentTaskError(code, "편지를 생성할 수 없습니다.") from None
        except Exception:
            await self._repository.fail(
                job.resource_id, work.token, "LETTER_GENERATION_RETRY", retry=True
            )
            # Never log a provider exception or ValidationError containing diary/sensor content.
            raise RuntimeError("LETTER_GENERATION_RETRY") from None

    async def on_exhausted(self, job: QueueJob) -> None:
        await self._repository.exhausted(job.resource_id)


class LetterPublishHandler:
    def __init__(self, repository: SQLAlchemyLetterRepository) -> None:
        self._repository = repository

    async def __call__(self, job: QueueJob) -> None:
        await self._repository.publish(job.resource_id)

    async def on_exhausted(self, job: QueueJob) -> None:
        # Publication transaction failure must remain retryable, not strand a completed letter.
        raise RuntimeError("LETTER_PUBLICATION_REQUIRES_RETRY")


def letter_notification_body(personality: str) -> str:
    return {
        "OUTGOING": "너한테 편지 썼어! 같이 읽어 보자!",
        "CHIC": "편지 써 뒀어. 시간 날 때 읽어.",
        "CUTE": "너에게 보내는 편지가 도착했어요!",
        "CRUSH": "너에게 하고 싶은 말을 편지에 담았어.",
        "INTROVERTED": "조그만 편지 써 봤어. 읽어 줄래?",
        "CHUNGCHEONG": "편지 한 통 써 뒀슈. 천천히 읽어 봐유.",
    }.get(personality, "식물이 보낸 편지를 확인해 주세요.")
