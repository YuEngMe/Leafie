from datetime import UTC, datetime
from typing import Protocol
from uuid import uuid4

from sqlalchemy import Date, cast, exists, extract, func, select
from sqlalchemy.dialects.postgresql import insert

from app.db.session import Database
from app.integrations.queue import JobQueue
from app.models.care import CareEvent
from app.models.enums import CareEventStatus, CareEventType
from app.models.notification import Notification
from app.models.plant import Plant
from app.models.user import UserProfile
from app.schemas.queue import JobType, QueueJob


class CareNotificationRepository(Protocol):
    async def collect(self, now: datetime) -> int: ...


class SQLAlchemyCareNotificationRepository:
    def __init__(self, database: Database, queue: JobQueue) -> None:
        self._database = database
        self._queue = queue

    async def collect(self, now: datetime) -> int:
        local_now = func.timezone(UserProfile.timezone, now)
        local_date = cast(local_now, Date)
        async with self._database.session_context() as session:
            rows = (
                await session.execute(
                    select(
                        CareEvent.id,
                        CareEvent.type,
                        CareEvent.due_date,
                        Plant.id.label("plant_id"),
                        Plant.user_id,
                        Plant.nickname,
                        Plant.personality_type,
                        local_date.label("local_date"),
                    )
                    .join(Plant, Plant.id == CareEvent.plant_id)
                    .join(UserProfile, UserProfile.user_id == Plant.user_id)
                    .where(
                        CareEvent.status == CareEventStatus.SCHEDULED.value,
                        CareEvent.type.in_(
                            (
                                CareEventType.WATERING.value,
                                CareEventType.REPOTTING.value,
                            )
                        ),
                        CareEvent.due_date <= local_date,
                        Plant.deleted_at.is_(None),
                        UserProfile.deleted_at.is_(None),
                        extract("hour", local_now) == 9,
                        ~exists(
                            select(Notification.id).where(
                                Notification.user_id == Plant.user_id,
                                Notification.type == "CARE_DUE",
                                Notification.source_type == "CARE_EVENT",
                                Notification.source_id == CareEvent.id,
                            )
                        ),
                    )
                )
            ).all()

            created = 0
            for row in rows:
                notification_id = uuid4()
                title, body = care_notification_copy(
                    row.nickname,
                    row.personality_type,
                    row.type,
                    overdue=row.due_date < row.local_date,
                )
                inserted_id = await session.scalar(
                    insert(Notification)
                    .values(
                        id=notification_id,
                        user_id=row.user_id,
                        plant_id=row.plant_id,
                        type="CARE_DUE",
                        title=title,
                        body=body,
                        source_type="CARE_EVENT",
                        source_id=row.id,
                        created_at=now,
                    )
                    .on_conflict_do_nothing(
                        index_elements=("user_id", "type", "source_type", "source_id"),
                        index_where=Notification.source_id.is_not(None),
                    )
                    .returning(Notification.id)
                )
                if inserted_id is None:
                    continue
                await self._queue.enqueue(
                    QueueJob(
                        job_type=JobType.PUSH_NOTIFICATION_SEND,
                        resource_id=inserted_id,
                        trace_id=f"care:{row.id}",
                    ),
                    session=session,
                )
                created += 1
            return created


class CareNotificationCollectHandler:
    def __init__(self, repository: CareNotificationRepository) -> None:
        self._repository = repository

    async def __call__(self, job: QueueJob) -> None:
        del job
        await self._repository.collect(datetime.now(UTC))


def care_notification_copy(
    nickname: str,
    personality_type: str,
    event_type: str,
    *,
    overdue: bool,
) -> tuple[str, str]:
    action = "물 줄" if event_type == CareEventType.WATERING.value else "분갈이할"
    title = "미룬 관리가 있어요" if overdue else "오늘의 식물 관리"
    messages = {
        "OUTGOING": f"{nickname}에게 {action} 시간이야! 같이 해보자!",
        "CHIC": f"{nickname} {action} 때야. 확인해.",
        "CUTE": f"{nickname}에게 {action} 시간이에요!",
        "CRUSH": f"{nickname}이 기다리고 있어. {action} 시간이야.",
        "INTROVERTED": f"{nickname}에게... {action} 때가 됐어.",
        "CHUNGCHEONG": f"{nickname}에게 {action} 때가 됐슈. 천천히 해유.",
    }
    body = messages.get(personality_type, f"{nickname}에게 {action} 시간이에요.")
    if overdue:
        body = f"예정일이 지났어요. {body}"
    return title, body
