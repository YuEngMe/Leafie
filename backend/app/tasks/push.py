import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID

from sqlalchemy import select, update

from app.db.session import Database
from app.integrations.push import PushGateway, PushPermanentError
from app.models.notification import Notification
from app.models.user import DeviceToken, UserProfile
from app.schemas.queue import QueueJob
from app.tasks.base import PermanentTaskError

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class PushWork:
    notification_id: UUID
    plant_id: UUID | None
    title: str
    body: str
    installation_ids: list[str]


class PushRepository(Protocol):
    async def load(self, notification_id: UUID) -> PushWork | None: ...

    async def revoke_tokens(self, tokens: list[str]) -> None: ...


class SQLAlchemyPushRepository:
    def __init__(self, database: Database) -> None:
        self._database = database

    async def load(self, notification_id: UUID) -> PushWork | None:
        async with self._database.session_context() as session:
            row = (
                await session.execute(
                    select(Notification, UserProfile.push_enabled)
                    .join(UserProfile, UserProfile.user_id == Notification.user_id)
                    .where(Notification.id == notification_id)
                )
            ).one_or_none()
            if row is None:
                return None
            notification, push_enabled = row
            installation_ids: list[str] = []
            if push_enabled:
                installation_ids = list(
                    (
                        await session.scalars(
                            select(DeviceToken.token).where(
                                DeviceToken.user_id == notification.user_id,
                                DeviceToken.revoked_at.is_(None),
                            )
                        )
                    ).all()
                )
            return PushWork(
                notification_id=notification.id,
                plant_id=notification.plant_id,
                title=notification.title,
                body=notification.body,
                installation_ids=installation_ids,
            )

    async def revoke_tokens(self, tokens: list[str]) -> None:
        if not tokens:
            return
        async with self._database.session_context() as session:
            await session.execute(
                update(DeviceToken)
                .where(DeviceToken.token.in_(tokens), DeviceToken.revoked_at.is_(None))
                .values(revoked_at=datetime.now(UTC))
            )


class PushNotificationHandler:
    def __init__(self, repository: PushRepository, gateway: PushGateway) -> None:
        self._repository = repository
        self._gateway = gateway

    async def __call__(self, job: QueueJob) -> None:
        work = await self._repository.load(job.resource_id)
        if work is None or not work.installation_ids:
            return
        try:
            result = await self._gateway.send(
                notification_id=str(work.notification_id),
                title=work.title,
                body=work.body,
                data={
                    "notification_id": str(work.notification_id),
                    "plant_id": str(work.plant_id) if work.plant_id else "",
                },
                installation_ids=work.installation_ids,
            )
        except PushPermanentError as exc:
            raise PermanentTaskError(str(exc), "푸시 설정 또는 요청을 확인해 주세요.") from exc

        await self._repository.revoke_tokens(result.invalid_tokens)
        if result.permanent_failures:
            logger.warning(
                "Push messages permanently failed notification_id=%s count=%s",
                work.notification_id,
                result.permanent_failures,
            )
        if result.retryable_failures:
            raise RuntimeError(
                f"FCM retryable failures: {result.retryable_failures}"
            )
