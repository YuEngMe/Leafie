from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
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
from app.schemas.care import CareEventCompleteRequest, CareEventCreateRequest
from app.services.care import CareEventContext, CareService, OwnedPlantContext
from app.services.plant import today_in_timezone


class FakeCareRepository:
    def __init__(self, user_id: UUID, plant_id: UUID) -> None:
        self.user_id = user_id
        self.plant_id = plant_id
        self.timezone = "Asia/Seoul"
        self.default_repotting_interval_days: int | None = 365
        self.events: dict[UUID, CareEvent] = {}
        self.schedules: dict[UUID, CareSchedule] = {}
        self.flush_count = 0

    async def get_owned_plant(
        self, plant_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> OwnedPlantContext | None:
        if plant_id != self.plant_id or user_id != self.user_id:
            return None
        return OwnedPlantContext(
            plant_id=plant_id,
            timezone=self.timezone,
            default_repotting_interval_days=self.default_repotting_interval_days,
        )

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

    async def get_scheduled_repotting_for_update(self, plant_id: UUID) -> CareEvent | None:
        return next(
            (
                event
                for event in self.events.values()
                if event.plant_id == plant_id
                and event.type == "REPOTTING"
                and event.status == CareEventStatus.SCHEDULED.value
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

    async def get_repotting_schedule_for_update(self, plant_id: UUID) -> CareSchedule | None:
        return next(
            (
                schedule
                for schedule in self.schedules.values()
                if schedule.plant_id == plant_id and schedule.type == "REPOTTING"
            ),
            None,
        )

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

    async def add(self, instance: object) -> None:
        if isinstance(instance, CareEvent):
            self.events[instance.id] = instance
        elif isinstance(instance, CareSchedule):
            self.schedules[instance.id] = instance

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
        "care_type": "FERTILIZING",
        "due_date": today_in_timezone("Asia/Seoul"),
    }
    payload.update(overrides)
    return CareEventCreateRequest.model_validate(payload)


def make_schedule(
    plant_id: UUID,
    *,
    care_type: str = "WATERING",
    interval_days: int = 10,
) -> CareSchedule:
    today = today_in_timezone("Asia/Seoul")
    return CareSchedule(
        id=uuid4(),
        plant_id=plant_id,
        type=care_type,
        interval_days=interval_days,
        next_due_date=today,
        enabled=True,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )


def make_scheduled_event(plant_id: UUID, schedule: CareSchedule) -> CareEvent:
    now = datetime.now(UTC)
    return CareEvent(
        id=uuid4(),
        plant_id=plant_id,
        schedule_id=schedule.id,
        type=schedule.type,
        status=CareEventStatus.SCHEDULED.value,
        source=CareEventSource.AUTO_SCHEDULE.value,
        due_date=today_in_timezone("Asia/Seoul"),
        created_at=now,
        updated_at=now,
    )


def test_event_schema_accepts_only_repotting_and_fertilizing() -> None:
    for care_type in ("REPOTTING", "FERTILIZING"):
        assert make_event_request(care_type=care_type).care_type.value == care_type
    for care_type in ("WATERING", "PRUNING", "CUSTOM"):
        with pytest.raises(ValidationError):
            make_event_request(care_type=care_type)
    with pytest.raises(ValidationError):
        make_event_request(type="FERTILIZING")
    with pytest.raises(ValidationError):
        make_event_request(title="비료 주기")


async def test_fertilizing_is_idempotent_and_rejects_key_reuse() -> None:
    service, repository, user_id, plant_id = build_service()
    request = make_event_request()

    first = await service.create_event(user_id, plant_id, request)
    second = await service.create_event(user_id, plant_id, request)

    assert first.created is True
    assert second.created is False
    assert second.response == first.response
    assert len(repository.events) == 1

    with pytest.raises(AppError) as error:
        await service.create_event(
            user_id,
            plant_id,
            make_event_request(
                client_event_id=request.client_event_id,
                due_date=request.due_date + timedelta(days=1),
            ),
        )
    assert error.value.code == "CLIENT_EVENT_ID_REUSED"


async def test_retry_returns_existing_result_even_after_due_date(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    service, repository, user_id, plant_id = build_service()
    request = make_event_request()
    first = await service.create_event(user_id, plant_id, request)
    monkeypatch.setattr(
        "app.services.care.today_in_timezone",
        lambda _timezone: request.due_date + timedelta(days=1),
    )

    replay = await service.create_event(user_id, plant_id, request)

    assert replay.created is False
    assert replay.response == first.response
    assert len(repository.events) == 1


async def test_event_allows_today_and_future_but_rejects_past() -> None:
    service, repository, user_id, plant_id = build_service()
    today = today_in_timezone(repository.timezone)

    await service.create_event(user_id, plant_id, make_event_request(due_date=today))
    await service.create_event(
        user_id,
        plant_id,
        make_event_request(due_date=today + timedelta(days=1)),
    )
    with pytest.raises(AppError) as error:
        await service.create_event(
            user_id,
            plant_id,
            make_event_request(due_date=today - timedelta(days=1)),
        )
    assert error.value.code == "PAST_DUE_DATE_NOT_ALLOWED"


async def test_repotting_updates_existing_pending_event_and_schedule() -> None:
    service, repository, user_id, plant_id = build_service()
    schedule = make_schedule(plant_id, care_type="REPOTTING", interval_days=365)
    event = make_scheduled_event(plant_id, schedule)
    repository.schedules[schedule.id] = schedule
    repository.events[event.id] = event
    due_date = today_in_timezone(repository.timezone) + timedelta(days=7)
    request = make_event_request(care_type="REPOTTING", due_date=due_date)

    result = await service.create_event(user_id, plant_id, request)

    assert result.created is False
    assert result.response.id == event.id
    assert result.response.care_type.value == "REPOTTING"
    assert event.due_date == due_date
    assert event.client_event_id == request.client_event_id
    assert schedule.next_due_date == due_date
    assert len(repository.events) == 1


async def test_repotting_creates_recurring_schedule_when_missing() -> None:
    service, repository, user_id, plant_id = build_service()
    due_date = today_in_timezone(repository.timezone) + timedelta(days=7)

    result = await service.create_event(
        user_id,
        plant_id,
        make_event_request(care_type="REPOTTING", due_date=due_date),
    )

    assert result.created is True
    schedule = next(iter(repository.schedules.values()))
    event = next(iter(repository.events.values()))
    assert schedule.interval_days == 365
    assert schedule.next_due_date == due_date
    assert event.schedule_id == schedule.id


async def test_repotting_without_species_interval_is_one_time() -> None:
    service, repository, user_id, plant_id = build_service()
    repository.default_repotting_interval_days = None

    result = await service.create_event(
        user_id,
        plant_id,
        make_event_request(care_type="REPOTTING"),
    )

    assert result.created is True
    assert repository.schedules == {}
    assert result.response.schedule_id is None


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


async def test_late_retroactive_completion_moves_to_first_future_interval() -> None:
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
    assert response.next_event.due_date == today + timedelta(days=5)


async def test_completion_rejects_future_date_and_cancelled_event() -> None:
    service, repository, user_id, plant_id = build_service()
    schedule = make_schedule(plant_id)
    event = make_scheduled_event(plant_id, schedule)
    repository.schedules[schedule.id] = schedule
    repository.events[event.id] = event
    tomorrow = today_in_timezone(repository.timezone) + timedelta(days=1)

    with pytest.raises(AppError) as future_error:
        await service.complete_event(
            user_id,
            event.id,
            CareEventCompleteRequest(performed_on=tomorrow),
        )
    assert future_error.value.code == "FUTURE_DATE_NOT_ALLOWED"

    event.status = CareEventStatus.CANCELLED.value
    with pytest.raises(AppError) as cancelled_error:
        await service.complete_event(user_id, event.id, CareEventCompleteRequest())
    assert cancelled_error.value.code == "CARE_EVENT_CANCELLED"


def test_invalid_timezone_format_uses_seoul_fallback() -> None:
    assert today_in_timezone("") == today_in_timezone("Asia/Seoul")


def test_care_http_routes_create_and_complete(monkeypatch: pytest.MonkeyPatch) -> None:
    service, repository, user_id, plant_id = build_service()
    schedule = make_schedule(plant_id)
    event = make_scheduled_event(plant_id, schedule)
    repository.schedules[schedule.id] = schedule
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
    create_payload = make_event_request().model_dump(mode="json")
    today = today_in_timezone(repository.timezone)
    repotting_payload = make_event_request(
        care_type="REPOTTING",
        due_date=today + timedelta(days=7),
    ).model_dump(mode="json")
    moved_repotting_payload = make_event_request(
        care_type="REPOTTING",
        due_date=today + timedelta(days=14),
    ).model_dump(mode="json")

    with TestClient(application) as client:
        created = client.post(f"/api/v1/plants/{plant_id}/care-events", json=create_payload)
        replayed = client.post(f"/api/v1/plants/{plant_id}/care-events", json=create_payload)
        reused_key = client.post(
            f"/api/v1/plants/{plant_id}/care-events",
            json={**create_payload, "due_date": (today + timedelta(days=1)).isoformat()},
        )
        repotting_created = client.post(
            f"/api/v1/plants/{plant_id}/care-events", json=repotting_payload
        )
        repotting_moved = client.post(
            f"/api/v1/plants/{plant_id}/care-events", json=moved_repotting_payload
        )
        invalid_type = client.post(
            f"/api/v1/plants/{plant_id}/care-events",
            json={**create_payload, "care_type": "CUSTOM"},
        )
        past_due = client.post(
            f"/api/v1/plants/{plant_id}/care-events",
            json=make_event_request(due_date=today - timedelta(days=1)).model_dump(mode="json"),
        )
        completed = client.post(f"/api/v1/care-events/{event.id}/complete", json={})
        removed_memo_route = client.put(
            f"/api/v1/plants/{plant_id}/daily-memos/2026-09-17",
            json={"content": "없어진 메모"},
        )

    assert created.status_code == 201
    assert created.json()["care_type"] == "FERTILIZING"
    assert "type" not in created.json()
    assert "title" not in created.json()
    assert replayed.status_code == 200
    assert replayed.json()["id"] == created.json()["id"]
    assert reused_key.status_code == 409
    assert reused_key.json()["error"]["code"] == "CLIENT_EVENT_ID_REUSED"
    assert repotting_created.status_code == 201
    assert repotting_moved.status_code == 200
    assert repotting_moved.json()["id"] == repotting_created.json()["id"]
    assert repotting_moved.json()["due_date"] == moved_repotting_payload["due_date"]
    assert invalid_type.status_code == 422
    assert past_due.status_code == 400
    assert past_due.json()["error"]["code"] == "PAST_DUE_DATE_NOT_ALLOWED"
    assert completed.status_code == 200
    assert completed.json()["status"] == "COMPLETED"
    assert completed.json()["next_event"] is not None
    assert removed_memo_route.status_code == 404
