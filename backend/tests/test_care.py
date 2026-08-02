from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.dependencies import get_current_user, get_database_session
from app.api.v1 import care as care_api
from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.care import CareEvent, CareSchedule
from app.models.enums import CareEventSource, CareEventStatus
from app.models.plant import PlantDailyMemo
from app.schemas.care import (
    CareEventCompleteRequest,
    CareEventCreateRequest,
    DailyMemoUpsertRequest,
)
from app.services.care import CareEventContext, CareService, OwnedPlantContext
from app.services.plant import today_in_timezone


class FakeCareRepository:
    def __init__(self, user_id: UUID, plant_id: UUID) -> None:
        self.user_id = user_id
        self.plant_id = plant_id
        self.timezone = "Asia/Seoul"
        self.events: dict[UUID, CareEvent] = {}
        self.schedules: dict[UUID, CareSchedule] = {}
        self.memos: dict[date, PlantDailyMemo] = {}
        self.flush_count = 0

    async def get_owned_plant(
        self, plant_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> OwnedPlantContext | None:
        if plant_id != self.plant_id or user_id != self.user_id:
            return None
        return OwnedPlantContext(plant_id=plant_id, timezone=self.timezone)

    async def get_event_by_client_id(
        self, plant_id: UUID, client_event_id: UUID
    ) -> CareEvent | None:
        return next(
            (
                event
                for event in self.events.values()
                if event.plant_id == plant_id and event.client_event_id == client_event_id
            ),
            None,
        )

    async def get_event_for_update(
        self, event_id: UUID, user_id: UUID
    ) -> CareEventContext | None:
        event = self.events.get(event_id)
        if event is None or event.plant_id != self.plant_id or user_id != self.user_id:
            return None
        return CareEventContext(event=event, timezone=self.timezone)

    async def get_schedule_for_update(self, schedule_id: UUID) -> CareSchedule | None:
        return self.schedules.get(schedule_id)

    async def get_scheduled_event(self, schedule_id: UUID) -> CareEvent | None:
        return next(
            (
                event
                for event in self.events.values()
                if event.schedule_id == schedule_id
                and event.status == CareEventStatus.SCHEDULED.value
            ),
            None,
        )

    async def get_memo(
        self, plant_id: UUID, memo_date: date, *, lock: bool = False
    ) -> PlantDailyMemo | None:
        if plant_id != self.plant_id:
            return None
        return self.memos.get(memo_date)

    async def add(self, instance: object) -> None:
        if isinstance(instance, CareEvent):
            self.events[instance.id] = instance
        elif isinstance(instance, PlantDailyMemo):
            self.memos[instance.memo_date] = instance

    async def delete(self, instance: object) -> None:
        if isinstance(instance, PlantDailyMemo):
            self.memos.pop(instance.memo_date, None)

    async def flush(self) -> None:
        self.flush_count += 1


def build_service() -> tuple[CareService, FakeCareRepository, UUID, UUID]:
    user_id = uuid4()
    plant_id = uuid4()
    repository = FakeCareRepository(user_id, plant_id)
    return CareService(repository), repository, user_id, plant_id


def make_event_request(**overrides: object) -> CareEventCreateRequest:
    payload: dict[str, object] = {
        "client_event_id": uuid4(),
        "type": "CUSTOM",
        "title": "화분 방향 돌리기",
        "due_date": today_in_timezone("Asia/Seoul"),
    }
    payload.update(overrides)
    return CareEventCreateRequest.model_validate(payload)


def make_schedule(plant_id: UUID, *, interval_days: int = 10) -> CareSchedule:
    today = today_in_timezone("Asia/Seoul")
    return CareSchedule(
        id=uuid4(),
        plant_id=plant_id,
        type="WATERING",
        interval_days=interval_days,
        next_due_date=today,
        enabled=True,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )


def make_scheduled_event(plant_id: UUID, schedule: CareSchedule | None = None) -> CareEvent:
    now = datetime.now(UTC)
    return CareEvent(
        id=uuid4(),
        plant_id=plant_id,
        schedule_id=schedule.id if schedule is not None else None,
        type="WATERING" if schedule is not None else "CUSTOM",
        title=None if schedule is not None else "잎 닦기",
        status=CareEventStatus.SCHEDULED.value,
        source=(
            CareEventSource.AUTO_SCHEDULE.value
            if schedule is not None
            else CareEventSource.USER_CREATED.value
        ),
        due_date=today_in_timezone("Asia/Seoul"),
        created_at=now,
        updated_at=now,
    )


def test_one_time_event_schema_rejects_recurring_types_and_blank_title() -> None:
    for care_type in ("WATERING", "REPOTTING"):
        with pytest.raises(ValidationError):
            make_event_request(type=care_type)
    with pytest.raises(ValidationError):
        make_event_request(title=" \t\n ")


async def test_one_time_event_is_idempotent_and_rejects_key_reuse() -> None:
    service, repository, user_id, plant_id = build_service()
    request = make_event_request()

    first = await service.create_one_time_event(user_id, plant_id, request)
    second = await service.create_one_time_event(user_id, plant_id, request)

    assert first.created is True
    assert second.created is False
    assert second.response == first.response
    assert len(repository.events) == 1

    with pytest.raises(AppError) as error:
        await service.create_one_time_event(
            user_id,
            plant_id,
            make_event_request(client_event_id=request.client_event_id, title="다른 일정"),
        )
    assert error.value.code == "CLIENT_EVENT_ID_REUSED"


async def test_event_retry_still_returns_existing_result_after_due_date(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    service, repository, user_id, plant_id = build_service()
    request = make_event_request()
    first = await service.create_one_time_event(user_id, plant_id, request)
    tomorrow = request.due_date + timedelta(days=1)
    monkeypatch.setattr("app.services.care.today_in_timezone", lambda _timezone: tomorrow)

    replay = await service.create_one_time_event(user_id, plant_id, request)

    assert replay.created is False
    assert replay.response == first.response
    assert len(repository.events) == 1


async def test_one_time_event_allows_today_and_future_but_rejects_past() -> None:
    service, repository, user_id, plant_id = build_service()
    today = today_in_timezone(repository.timezone)

    await service.create_one_time_event(user_id, plant_id, make_event_request(due_date=today))
    await service.create_one_time_event(
        user_id, plant_id, make_event_request(due_date=today + timedelta(days=1))
    )
    with pytest.raises(AppError) as error:
        await service.create_one_time_event(
            user_id, plant_id, make_event_request(due_date=today - timedelta(days=1))
        )
    assert error.value.code == "PAST_DUE_DATE_NOT_ALLOWED"


async def test_recurring_completion_uses_performed_date_and_creates_next_event() -> None:
    service, repository, user_id, plant_id = build_service()
    schedule = make_schedule(plant_id, interval_days=10)
    event = make_scheduled_event(plant_id, schedule)
    repository.schedules[schedule.id] = schedule
    repository.events[event.id] = event
    today = today_in_timezone(repository.timezone)
    performed_on = today - timedelta(days=2)

    response = await service.complete_event(
        user_id,
        event.id,
        CareEventCompleteRequest(performed_on=performed_on),
    )

    assert response.status == CareEventStatus.COMPLETED
    assert response.performed_on == performed_on
    assert response.recorded_at is not None
    assert response.next_event is not None
    assert response.next_event.due_date == performed_on + timedelta(days=10)
    assert schedule.next_due_date == response.next_event.due_date
    assert len(repository.events) == 2

    replay = await service.complete_event(
        user_id,
        event.id,
        CareEventCompleteRequest(performed_on=performed_on),
    )
    assert replay.next_event == response.next_event
    assert len(repository.events) == 2


async def test_late_retroactive_completion_moves_next_due_date_to_first_current_interval() -> None:
    service, repository, user_id, plant_id = build_service()
    schedule = make_schedule(plant_id, interval_days=10)
    event = make_scheduled_event(plant_id, schedule)
    repository.schedules[schedule.id] = schedule
    repository.events[event.id] = event
    today = today_in_timezone(repository.timezone)

    response = await service.complete_event(
        user_id,
        event.id,
        CareEventCompleteRequest(performed_on=today - timedelta(days=35)),
    )

    assert response.next_event is not None
    assert response.next_event.due_date == today - timedelta(days=5) + timedelta(days=10)


async def test_completion_rejects_future_date_and_cancelled_event() -> None:
    service, repository, user_id, plant_id = build_service()
    event = make_scheduled_event(plant_id)
    repository.events[event.id] = event
    tomorrow = today_in_timezone(repository.timezone) + timedelta(days=1)

    with pytest.raises(AppError) as future_error:
        await service.complete_event(
            user_id, event.id, CareEventCompleteRequest(performed_on=tomorrow)
        )
    assert future_error.value.code == "FUTURE_DATE_NOT_ALLOWED"

    event.status = CareEventStatus.CANCELLED.value
    with pytest.raises(AppError) as cancelled_error:
        await service.complete_event(user_id, event.id, CareEventCompleteRequest())
    assert cancelled_error.value.code == "CARE_EVENT_CANCELLED"


def test_daily_memo_schema_accepts_up_to_500_nonblank_characters() -> None:
    assert DailyMemoUpsertRequest(content="  메모  ").content == "메모"
    assert len(DailyMemoUpsertRequest(content="가" * 500).content) == 500
    for invalid in (" \t\n ", "가" * 501):
        with pytest.raises(ValidationError):
            DailyMemoUpsertRequest(content=invalid)


def test_invalid_timezone_format_uses_seoul_fallback() -> None:
    assert today_in_timezone("") == today_in_timezone("Asia/Seoul")


async def test_daily_memo_upsert_and_delete_are_idempotent() -> None:
    service, repository, user_id, plant_id = build_service()
    today = today_in_timezone(repository.timezone)

    created = await service.upsert_daily_memo(
        user_id, plant_id, today, DailyMemoUpsertRequest(content="새잎 확인")
    )
    updated = await service.upsert_daily_memo(
        user_id, plant_id, today, DailyMemoUpsertRequest(content="물 주기 완료")
    )
    assert created.created is True
    assert updated.created is False
    assert updated.response.content == "물 주기 완료"
    assert len(repository.memos) == 1

    await service.delete_daily_memo(user_id, plant_id, today)
    await service.delete_daily_memo(user_id, plant_id, today)
    assert repository.memos == {}


async def test_daily_memo_only_accepts_today() -> None:
    service, repository, user_id, plant_id = build_service()
    yesterday = today_in_timezone(repository.timezone) - timedelta(days=1)

    with pytest.raises(AppError) as error:
        await service.upsert_daily_memo(
            user_id,
            plant_id,
            yesterday,
            DailyMemoUpsertRequest(content="과거 메모"),
        )
    assert error.value.code == "DAILY_MEMO_DATE_NOT_TODAY"


def test_care_http_routes_create_complete_and_delete_memo(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    service, repository, user_id, plant_id = build_service()
    today = today_in_timezone(repository.timezone)
    event = make_scheduled_event(plant_id)
    repository.events[event.id] = event

    def fake_session() -> Iterator[object]:
        yield object()

    application = create_app()
    application.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=user_id,
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )
    application.dependency_overrides[get_database_session] = fake_session
    monkeypatch.setattr(care_api, "build_service", lambda _session: service)
    create_payload = make_event_request(due_date=today).model_dump(mode="json")

    with TestClient(application) as client:
        created = client.post(f"/api/v1/plants/{plant_id}/care-events", json=create_payload)
        replayed = client.post(f"/api/v1/plants/{plant_id}/care-events", json=create_payload)
        completed = client.post(f"/api/v1/care-events/{event.id}/complete", json={})
        memo = client.put(
            f"/api/v1/plants/{plant_id}/daily-memos/{today}",
            json={"content": "오늘 메모"},
        )
        deleted = client.delete(f"/api/v1/plants/{plant_id}/daily-memos/{today}")

    assert created.status_code == 201
    assert replayed.status_code == 200
    assert completed.status_code == 200
    assert memo.status_code == 201
    assert deleted.status_code == 204
