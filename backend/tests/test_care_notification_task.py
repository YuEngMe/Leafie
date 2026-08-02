from datetime import UTC, datetime
from uuid import uuid4

from app.schemas.queue import JobType, QueueJob
from app.tasks.care_notification import (
    CareNotificationCollectHandler,
    care_notification_copy,
)


class FakeRepository:
    def __init__(self) -> None:
        self.calls: list[datetime] = []

    async def collect(self, now: datetime) -> int:
        self.calls.append(now)
        return 2


def test_care_notification_copy_uses_event_state_and_personality() -> None:
    assert care_notification_copy("새싹이", "CHIC", "WATERING", overdue=False) == (
        "오늘의 식물 관리",
        "새싹이 물 줄 때야. 확인해.",
    )
    assert care_notification_copy("새싹이", "CHUNGCHEONG", "REPOTTING", overdue=True) == (
        "미룬 관리가 있어요",
        "예정일이 지났어요. 새싹이에게 분갈이할 때가 됐슈. 천천히 해유.",
    )


async def test_care_notification_handler_runs_collector_with_utc_time() -> None:
    repository = FakeRepository()
    handler = CareNotificationCollectHandler(repository)

    await handler(
        QueueJob(
            job_type=JobType.CARE_NOTIFICATION_COLLECT,
            resource_id=uuid4(),
            trace_id="cron:care-notifications",
        )
    )

    assert len(repository.calls) == 1
    assert repository.calls[0].tzinfo is UTC
