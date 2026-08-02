import base64
import binascii
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.notification import Notification
from app.models.user import DeviceToken
from app.schemas.notification import (
    DeviceRegisterRequest,
    DeviceResponse,
    NotificationListResponse,
    NotificationResponse,
)


class NotificationRepository(Protocol):
    async def list_notifications(
        self, user_id: UUID, unread_only: bool, offset: int, limit: int
    ) -> list[Notification]: ...

    async def get_notification(
        self, notification_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> Notification | None: ...

    async def mark_all_read(self, user_id: UUID, read_at: datetime) -> None: ...

    async def register_device(
        self, user_id: UUID, request: DeviceRegisterRequest, now: datetime
    ) -> DeviceToken: ...

    async def get_device(
        self, device_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> DeviceToken | None: ...

    async def flush(self) -> None: ...


class SQLAlchemyNotificationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_notifications(
        self, user_id: UUID, unread_only: bool, offset: int, limit: int
    ) -> list[Notification]:
        statement = select(Notification).where(Notification.user_id == user_id)
        if unread_only:
            statement = statement.where(Notification.read_at.is_(None))
        statement = statement.order_by(
            Notification.created_at.desc(), Notification.id.desc()
        )
        return list((await self._session.scalars(statement.offset(offset).limit(limit))).all())

    async def get_notification(
        self, notification_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> Notification | None:
        statement = select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user_id,
        )
        if lock:
            statement = statement.with_for_update()
        return await self._session.scalar(statement)

    async def mark_all_read(self, user_id: UUID, read_at: datetime) -> None:
        await self._session.execute(
            update(Notification)
            .where(Notification.user_id == user_id, Notification.read_at.is_(None))
            .values(read_at=read_at)
        )

    async def register_device(
        self, user_id: UUID, request: DeviceRegisterRequest, now: datetime
    ) -> DeviceToken:
        statement = (
            insert(DeviceToken)
            .values(
                id=uuid4(),
                user_id=user_id,
                platform=request.platform.value,
                token=request.token,
                last_used_at=now,
                created_at=now,
                revoked_at=None,
            )
            .on_conflict_do_update(
                index_elements=[DeviceToken.token],
                index_where=DeviceToken.revoked_at.is_(None),
                set_={
                    "user_id": user_id,
                    "platform": request.platform.value,
                    "last_used_at": now,
                },
            )
            .returning(DeviceToken)
        )
        device = await self._session.scalar(statement)
        assert device is not None
        return device

    async def get_device(
        self, device_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> DeviceToken | None:
        statement = select(DeviceToken).where(
            DeviceToken.id == device_id,
            DeviceToken.user_id == user_id,
            DeviceToken.revoked_at.is_(None),
        )
        if lock:
            statement = statement.with_for_update()
        return await self._session.scalar(statement)

    async def flush(self) -> None:
        await self._session.flush()


class NotificationService:
    def __init__(self, repository: NotificationRepository) -> None:
        self._repository = repository

    async def list(
        self,
        user_id: UUID,
        cursor: str | None,
        limit: int,
        unread_only: bool,
    ) -> NotificationListResponse:
        offset = decode_cursor(cursor)
        notifications = await self._repository.list_notifications(
            user_id, unread_only, offset, limit + 1
        )
        has_next = len(notifications) > limit
        return NotificationListResponse(
            items=[notification_response(item) for item in notifications[:limit]],
            next_cursor=encode_cursor(offset + limit) if has_next else None,
            has_next=has_next,
        )

    async def mark_read(self, user_id: UUID, notification_id: UUID) -> NotificationResponse:
        notification = await self._repository.get_notification(
            notification_id, user_id, lock=True
        )
        if notification is None:
            raise AppError(
                code="NOTIFICATION_NOT_FOUND",
                message="알림을 찾을 수 없습니다.",
                status_code=404,
            )
        if notification.read_at is None:
            notification.read_at = datetime.now(UTC)
            await self._repository.flush()
        return notification_response(notification)

    async def mark_all_read(self, user_id: UUID) -> None:
        await self._repository.mark_all_read(user_id, datetime.now(UTC))

    async def register_device(
        self, user_id: UUID, request: DeviceRegisterRequest
    ) -> DeviceResponse:
        device = await self._repository.register_device(user_id, request, datetime.now(UTC))
        return device_response(device)

    async def revoke_device(self, user_id: UUID, device_id: UUID) -> None:
        device = await self._repository.get_device(device_id, user_id, lock=True)
        if device is None:
            raise AppError(
                code="DEVICE_NOT_FOUND",
                message="기기를 찾을 수 없습니다.",
                status_code=404,
            )
        device.revoked_at = datetime.now(UTC)
        await self._repository.flush()


def notification_response(notification: Notification) -> NotificationResponse:
    return NotificationResponse(
        id=notification.id,
        plant_id=notification.plant_id,
        type=notification.type,
        title=notification.title,
        body=notification.body,
        source_type=notification.source_type,
        source_id=notification.source_id,
        read_at=notification.read_at,
        created_at=notification.created_at,
    )


def device_response(device: DeviceToken) -> DeviceResponse:
    return DeviceResponse(
        id=device.id,
        platform=device.platform,
        created_at=device.created_at,
    )


def encode_cursor(offset: int) -> str:
    return base64.urlsafe_b64encode(str(offset).encode()).decode().rstrip("=")


def decode_cursor(cursor: str | None) -> int:
    if cursor is None:
        return 0
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        offset = int(base64.urlsafe_b64decode(padded).decode())
    except (binascii.Error, ValueError, UnicodeDecodeError) as exc:
        raise AppError(
            code="INVALID_CURSOR",
            message="페이지 정보를 확인해 주세요.",
            status_code=422,
        ) from exc
    if offset < 0:
        raise AppError(
            code="INVALID_CURSOR",
            message="페이지 정보를 확인해 주세요.",
            status_code=422,
        )
    return offset
