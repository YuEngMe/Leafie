from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest
from pydantic import ValidationError

from app.core.errors import AppError
from app.models.notification import Notification
from app.models.user import DeviceToken
from app.schemas.notification import DeviceRegisterRequest
from app.services.notification import NotificationService


class FakeNotificationRepository:
    def __init__(self, user_id: UUID) -> None:
        self.user_id = user_id
        self.notifications: dict[UUID, Notification] = {}
        self.devices: dict[UUID, DeviceToken] = {}
        self.flush_count = 0

    async def list_notifications(
        self, user_id: UUID, unread_only: bool, offset: int, limit: int
    ) -> list[Notification]:
        items = [
            item
            for item in self.notifications.values()
            if item.user_id == user_id and (not unread_only or item.read_at is None)
        ]
        items.sort(key=lambda item: (item.created_at, item.id), reverse=True)
        return items[offset : offset + limit]

    async def get_notification(
        self, notification_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> Notification | None:
        item = self.notifications.get(notification_id)
        return item if item is not None and item.user_id == user_id else None

    async def mark_all_read(self, user_id: UUID, read_at: datetime) -> None:
        for item in self.notifications.values():
            if item.user_id == user_id and item.read_at is None:
                item.read_at = read_at

    async def register_device(
        self, user_id: UUID, request: DeviceRegisterRequest, now: datetime
    ) -> DeviceToken:
        existing = next(
            (
                item
                for item in self.devices.values()
                if item.token == request.installation_id and item.revoked_at is None
            ),
            None,
        )
        if existing is not None:
            existing.user_id = user_id
            existing.platform = request.platform.value
            existing.last_used_at = now
            return existing
        item = DeviceToken(
            id=uuid4(),
            user_id=user_id,
            platform=request.platform.value,
            token=request.installation_id,
            last_used_at=now,
            created_at=now,
        )
        self.devices[item.id] = item
        return item

    async def get_device(
        self, device_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> DeviceToken | None:
        item = self.devices.get(device_id)
        if item is None or item.user_id != user_id or item.revoked_at is not None:
            return None
        return item

    async def flush(self) -> None:
        self.flush_count += 1


def make_notification(
    user_id: UUID,
    *,
    created_at: datetime,
    read_at: datetime | None = None,
) -> Notification:
    return Notification(
        id=uuid4(),
        user_id=user_id,
        plant_id=uuid4(),
        type="CARE_DUE",
        title="물 줄 시간이에요",
        body="새싹이에게 물을 주세요.",
        source_type="CARE_EVENT",
        source_id=uuid4(),
        read_at=read_at,
        created_at=created_at,
    )


async def test_notification_list_paginates_and_filters_unread() -> None:
    user_id = uuid4()
    repository = FakeNotificationRepository(user_id)
    now = datetime(2026, 8, 2, tzinfo=UTC)
    items = [
        make_notification(user_id, created_at=now - timedelta(minutes=index))
        for index in range(3)
    ]
    items[1].read_at = now
    repository.notifications = {item.id: item for item in items}
    service = NotificationService(repository)

    first = await service.list(user_id, None, 1, unread_only=False)
    second = await service.list(user_id, first.next_cursor, 2, unread_only=False)
    unread = await service.list(user_id, None, 20, unread_only=True)

    assert first.items[0].id == items[0].id
    assert first.has_next is True
    assert [item.id for item in second.items] == [items[1].id, items[2].id]
    assert second.has_next is False
    assert [item.id for item in unread.items] == [items[0].id, items[2].id]


async def test_notification_read_operations_are_owned_and_idempotent() -> None:
    user_id = uuid4()
    other_user_id = uuid4()
    repository = FakeNotificationRepository(user_id)
    first = make_notification(user_id, created_at=datetime(2026, 8, 2, tzinfo=UTC))
    second = make_notification(user_id, created_at=datetime(2026, 8, 1, tzinfo=UTC))
    repository.notifications = {first.id: first, second.id: second}
    service = NotificationService(repository)

    response = await service.mark_read(user_id, first.id)
    original_read_at = response.read_at
    replay = await service.mark_read(user_id, first.id)
    await service.mark_all_read(user_id)

    assert original_read_at is not None
    assert replay.read_at == original_read_at
    assert second.read_at is not None
    assert repository.flush_count == 1

    with pytest.raises(AppError) as error:
        await service.mark_read(other_user_id, first.id)
    assert error.value.code == "NOTIFICATION_NOT_FOUND"


async def test_device_registration_reuses_token_and_revoke_checks_owner() -> None:
    user_id = uuid4()
    other_user_id = uuid4()
    repository = FakeNotificationRepository(user_id)
    service = NotificationService(repository)
    request = DeviceRegisterRequest(platform="IOS", installation_id=" device-fid ")

    first = await service.register_device(user_id, request)
    first_used_at = repository.devices[first.id].last_used_at
    replay = await service.register_device(
        other_user_id,
        DeviceRegisterRequest(platform="ANDROID", installation_id="device-fid"),
    )

    assert replay.id == first.id
    assert repository.devices[replay.id].user_id == other_user_id
    assert replay.platform == "ANDROID"
    assert repository.devices[replay.id].last_used_at >= first_used_at
    assert len(repository.devices) == 1

    with pytest.raises(AppError) as error:
        await service.revoke_device(user_id, first.id)
    assert error.value.code == "DEVICE_NOT_FOUND"

    await service.revoke_device(other_user_id, first.id)
    assert repository.devices[first.id].revoked_at is not None

    registered_again = await service.register_device(user_id, request)
    assert registered_again.id != first.id
    assert repository.devices[registered_again.id].revoked_at is None
    assert len(repository.devices) == 2


def test_device_registration_rejects_blank_or_extra_fields() -> None:
    with pytest.raises(ValidationError):
        DeviceRegisterRequest(platform="IOS", installation_id="   ")
    with pytest.raises(ValidationError):
        DeviceRegisterRequest.model_validate(
            {"platform": "IOS", "installation_id": "fid", "unexpected": True}
        )


async def test_invalid_notification_cursor_is_rejected() -> None:
    user_id = uuid4()
    service = NotificationService(FakeNotificationRepository(user_id))

    with pytest.raises(AppError) as error:
        await service.list(user_id, "not-a-cursor", 20, unread_only=False)
    assert error.value.code == "INVALID_CURSOR"
