from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.dependencies import (
    get_current_user,
    get_database_session,
    get_job_queue,
    get_storage_gateway,
)
from app.api.v1 import plants as plants_api
from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.care import CareEvent
from app.models.enums import CareEventSource, CareEventStatus, MediaStatus
from app.models.media import MediaFile
from app.models.plant import Plant, PlantPersonalityChange, SpeciesCareGuide
from app.models.user import UserProfile
from app.schemas.plant import PlantAppearanceUpdateRequest, PlantUpdateRequest
from app.schemas.queue import JobType, QueueJob
from app.services.plant import today_in_timezone
from app.services.plant_management import (
    DeletePlantResult,
    PlantContext,
    PlantManagementService,
    days_together,
    home_background_phase,
)
from app.tasks.plant import PlantDeleteHandler


class FakeStorage:
    bucket_name = "leafie-media"

    def __init__(self) -> None:
        self.deleted: list[str] = []

    async def create_signed_download_url(self, object_path: str, *, expires_in: int) -> str:
        return f"https://storage.example/{object_path}?expires={expires_in}"

    async def delete_object(self, object_path: str) -> None:
        self.deleted.append(object_path)


class FakePlantRepository:
    def __init__(self, user_id: UUID, plants: list[Plant]) -> None:
        self.user_id = user_id
        self.profile = UserProfile(
            user_id=user_id,
            nickname="집사",
            timezone="Asia/Seoul",
            selected_plant_id=plants[0].id if plants else None,
        )
        self.guide = make_guide()
        self.plants = {plant.id: plant for plant in plants}
        self.media: dict[UUID, MediaFile] = {}
        self.events: list[CareEvent] = []
        self.unread_count = 0
        self.unread_letter_count = 0
        self.marked_media_for: list[UUID] = []
        self.personality_changes: list[PlantPersonalityChange] = []
        self.flush_count = 0

    async def get_profile(self, user_id: UUID, *, lock: bool = False) -> UserProfile | None:
        return self.profile if user_id == self.user_id else None

    async def list_plants(self, user_id: UUID) -> list[PlantContext]:
        if user_id != self.user_id:
            return []
        return [
            PlantContext(plant=plant, guide=self.guide, timezone=self.profile.timezone)
            for plant in sorted(self.plants.values(), key=lambda item: (item.created_at, item.id))
            if plant.deleted_at is None
        ]

    async def get_plant(
        self, user_id: UUID, plant_id: UUID, *, lock: bool = False
    ) -> PlantContext | None:
        plant = self.plants.get(plant_id)
        if user_id != self.user_id or plant is None or plant.deleted_at is not None:
            return None
        return PlantContext(plant=plant, guide=self.guide, timezone=self.profile.timezone)

    async def get_plant_for_delete(self, user_id: UUID, plant_id: UUID) -> Plant | None:
        if user_id != self.user_id:
            return None
        return self.plants.get(plant_id)

    async def get_media(self, user_id: UUID, media_file_id: UUID) -> MediaFile | None:
        media = self.media.get(media_file_id)
        if user_id != self.user_id or media is None or media.deleted_at is not None:
            return None
        return media

    async def list_active_events(self, plant_id: UUID) -> list[CareEvent]:
        return [
            event
            for event in self.events
            if event.plant_id == plant_id and event.status == CareEventStatus.SCHEDULED.value
        ]

    async def list_today_events(self, plant_id: UUID, today: date) -> list[CareEvent]:
        return [
            event
            for event in self.events
            if event.plant_id == plant_id
            and (
                (event.status == CareEventStatus.SCHEDULED.value and event.due_date == today)
                or (event.status == CareEventStatus.COMPLETED.value and event.performed_on == today)
            )
        ]

    async def list_calendar_events(
        self, plant_id: UUID, date_from: date, date_to: date, types: set[str]
    ) -> list[CareEvent]:
        return [
            event
            for event in self.events
            if event.plant_id == plant_id
            and event.type in types
            and (
                (
                    event.status == CareEventStatus.SCHEDULED.value
                    and date_from <= event.due_date <= date_to
                )
                or (
                    event.status == CareEventStatus.COMPLETED.value
                    and event.performed_on is not None
                    and date_from <= event.performed_on <= date_to
                )
            )
        ]

    async def count_unread_notifications(self, user_id: UUID) -> int:
        return self.unread_count if user_id == self.user_id else 0

    async def count_unread_letters(self, user_id: UUID) -> int:
        return self.unread_letter_count if user_id == self.user_id else 0

    async def oldest_remaining_plant_id(
        self, user_id: UUID, excluded_plant_id: UUID
    ) -> UUID | None:
        plants = [
            plant
            for plant in self.plants.values()
            if user_id == self.user_id
            and plant.id != excluded_plant_id
            and plant.deleted_at is None
        ]
        return min(plants, key=lambda item: (item.created_at, item.id)).id if plants else None

    async def mark_plant_media_deleted(self, plant_id: UUID, user_id: UUID) -> None:
        assert user_id == self.user_id
        self.marked_media_for.append(plant_id)
        plant = self.plants[plant_id]
        if plant.primary_media_file_id in self.media:
            media = self.media[plant.primary_media_file_id]
            media.status = MediaStatus.DELETED.value
            media.deleted_at = datetime.now(UTC)

    def add_personality_change(self, change: PlantPersonalityChange) -> None:
        self.personality_changes.append(change)

    async def flush(self) -> None:
        self.flush_count += 1


def make_guide() -> SpeciesCareGuide:
    return SpeciesCareGuide(
        species_reference_id="catalog:monstera",
        display_name="몬스테라",
        scientific_name="Monstera deliciosa",
        family_name="천남성과",
        category="FOLIAGE",
        aliases=[],
        care_profile={},
        diagnosis_profile={},
        source_references=[],
        active=True,
        updated_at=datetime.now(UTC),
    )


def make_plant(user_id: UUID, *, created_at: datetime | None = None) -> Plant:
    now = created_at or datetime.now(UTC)
    return Plant(
        id=uuid4(),
        user_id=user_id,
        client_registration_id=uuid4(),
        registration_request_hash="a" * 64,
        species_reference_id="catalog:monstera",
        nickname="초록이",
        species_selection_method="SEARCH",
        started_on=today_in_timezone("Asia/Seoul") - timedelta(days=10),
        place_name="거실",
        personality_type="OUTGOING",
        body_id="body_circle",
        color_id="color_green",
        hair_id="leaf",
        expression_id="expression_default",
        created_at=now,
        updated_at=now,
    )


def make_event(plant_id: UUID, due_date: date, *, completed: bool = False) -> CareEvent:
    now = datetime.now(UTC)
    return CareEvent(
        id=uuid4(),
        plant_id=plant_id,
        type="WATERING",
        status=(CareEventStatus.COMPLETED.value if completed else CareEventStatus.SCHEDULED.value),
        source=CareEventSource.AUTO_SCHEDULE.value,
        due_date=due_date,
        performed_on=due_date if completed else None,
        recorded_at=now if completed else None,
        created_at=now,
        updated_at=now,
    )


def build_service(
    plants: list[Plant] | None = None,
) -> tuple[PlantManagementService, FakePlantRepository, FakeStorage, UUID]:
    user_id = plants[0].user_id if plants else uuid4()
    repository = FakePlantRepository(user_id, plants or [])
    storage = FakeStorage()
    service = PlantManagementService(
        repository,
        storage,
        download_url_expires_seconds=300,
    )
    return service, repository, storage, user_id


def test_patch_schemas_require_nonblank_non_null_changes() -> None:
    for schema in (PlantUpdateRequest, PlantAppearanceUpdateRequest):
        with pytest.raises(ValidationError):
            schema.model_validate({})
    with pytest.raises(ValidationError):
        PlantUpdateRequest.model_validate({"nickname": "  "})
    with pytest.raises(ValidationError):
        PlantUpdateRequest.model_validate({"nickname": None})
    with pytest.raises(ValidationError):
        PlantUpdateRequest.model_validate({"personality_type": None})
    with pytest.raises(ValidationError):
        PlantUpdateRequest.model_validate({"personality_type": "UNKNOWN"})
    with pytest.raises(ValidationError):
        PlantAppearanceUpdateRequest.model_validate({"color_id": "  "})
    with pytest.raises(ValidationError):
        PlantAppearanceUpdateRequest.model_validate({"hair_id": "hair_unknown"})
    with pytest.raises(ValidationError):
        PlantAppearanceUpdateRequest.model_validate({"body_id": "body_unknown"})
    with pytest.raises(ValidationError):
        PlantAppearanceUpdateRequest.model_validate({"expression_id": "expression_unknown"})
    with pytest.raises(ValidationError):
        PlantUpdateRequest.model_validate({"pot_type": "PLASTIC"})
    with pytest.raises(ValidationError):
        PlantAppearanceUpdateRequest.model_validate({"accessory_id": "star"})


async def test_list_detail_and_partial_updates_return_owned_active_plants() -> None:
    user_id = uuid4()
    plant = make_plant(user_id)
    service, repository, _storage, _ = build_service([plant])
    listed = await service.list_plants(user_id)
    detail = await service.get_plant(user_id, plant.id)
    updated = await service.update_plant(user_id, plant.id, PlantUpdateRequest(nickname=" 새이름 "))
    appearance = await service.update_appearance(
        user_id,
        plant.id,
        PlantAppearanceUpdateRequest(
            body_id="body_square",
            color_id="color_yellow",
            hair_id="hair_monstera",
            expression_id="expression_happy",
        ),
    )

    assert listed.items[0].started_on == plant.started_on
    assert detail.nickname == "초록이"
    assert updated.nickname == "새이름"
    assert appearance.color_id == "color_yellow"
    assert appearance.hair_id == "hair_monstera"
    assert appearance.body_id.value == "body_square"
    assert appearance.expression_id.value == "expression_happy"

    with pytest.raises(AppError) as error:
        await service.get_plant(uuid4(), plant.id)
    assert error.value.code == "PLANT_NOT_FOUND"


async def test_personality_update_records_only_real_changes() -> None:
    user_id = uuid4()
    plant = make_plant(user_id)
    service, repository, _storage, _ = build_service([plant])

    updated = await service.update_plant(
        user_id,
        plant.id,
        PlantUpdateRequest(personality_type="CHIC"),
    )
    unchanged = await service.update_plant(
        user_id,
        plant.id,
        PlantUpdateRequest(personality_type="CHIC"),
    )

    assert updated.personality_type.value == "CHIC"
    assert unchanged.personality_type.value == "CHIC"
    assert len(repository.personality_changes) == 1
    assert repository.personality_changes[0].plant_id == plant.id
    assert repository.personality_changes[0].previous_personality_type == "OUTGOING"
    assert repository.personality_changes[0].new_personality_type == "CHIC"


def test_personality_update_route_validates_and_returns_changed_plant(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    user_id = uuid4()
    plant = make_plant(user_id)
    service, repository, storage, _ = build_service([plant])

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
    application.dependency_overrides[get_storage_gateway] = lambda: storage
    monkeypatch.setattr(
        plants_api,
        "build_management_service",
        lambda _session, _storage: service,
    )

    with TestClient(application) as client:
        changed = client.patch(
            f"/api/v1/plants/{plant.id}",
            json={"personality_type": "CHIC"},
        )
        repeated = client.patch(
            f"/api/v1/plants/{plant.id}",
            json={"personality_type": "CHIC"},
        )
        invalid = client.patch(
            f"/api/v1/plants/{plant.id}",
            json={"personality_type": "UNKNOWN"},
        )
        null_value = client.patch(
            f"/api/v1/plants/{plant.id}",
            json={"personality_type": None},
        )

    assert changed.status_code == 200
    assert changed.json()["personality_type"] == "CHIC"
    assert repeated.status_code == 200
    assert len(repository.personality_changes) == 1
    assert invalid.status_code == 422
    assert null_value.status_code == 422


async def test_agenda_derives_overdue_today_and_upcoming_without_moving_dates() -> None:
    user_id = uuid4()
    plant = make_plant(user_id)
    service, repository, _storage, _ = build_service([plant])
    today = today_in_timezone("Asia/Seoul")
    repository.events = [
        make_event(plant.id, today - timedelta(days=1)),
        make_event(plant.id, today),
        make_event(plant.id, today + timedelta(days=1)),
    ]

    response = await service.list_agenda(user_id, plant.id)

    assert [event.view_status.value for event in response.events] == [
        "OVERDUE",
        "TODAY",
        "UPCOMING",
    ]
    assert response.events[0].due_date == today - timedelta(days=1)


async def test_calendar_flattens_supported_events_and_excludes_cancelled() -> None:
    user_id = uuid4()
    plant = make_plant(user_id)
    service, repository, _storage, _ = build_service([plant])
    today = today_in_timezone("Asia/Seoul")
    scheduled = make_event(plant.id, today - timedelta(days=1))
    completed = make_event(plant.id, today, completed=True)
    completed.type = "REPOTTING"
    fertilizing = make_event(plant.id, today + timedelta(days=1))
    fertilizing.type = "FERTILIZING"
    cancelled = make_event(plant.id, today)
    cancelled.status = CareEventStatus.CANCELLED.value
    repository.events = [scheduled, completed, fertilizing, cancelled]
    response = await service.list_calendar(
        user_id,
        plant.id,
        today - timedelta(days=2),
        today + timedelta(days=2),
        None,
    )

    assert [item.id for item in response.items] == [scheduled.id, completed.id, fertilizing.id]
    assert response.items[0].view_status.value == "OVERDUE"
    assert response.items[1].date == completed.performed_on
    assert response.items[1].view_status.value == "COMPLETED"


async def test_calendar_filters_types_and_validates_range() -> None:
    user_id = uuid4()
    plant = make_plant(user_id)
    service, repository, _storage, _ = build_service([plant])
    today = today_in_timezone("Asia/Seoul")
    watering = make_event(plant.id, today)
    repotting = make_event(plant.id, today)
    repotting.type = "REPOTTING"
    repository.events = [watering, repotting]

    filtered = await service.list_calendar(user_id, plant.id, today, today, "REPOTTING")
    assert [item.id for item in filtered.items] == [repotting.id]

    with pytest.raises(AppError) as invalid_types:
        await service.list_calendar(user_id, plant.id, today, today, "CUSTOM")
    assert invalid_types.value.code == "INVALID_CALENDAR_TYPES"

    with pytest.raises(AppError) as reversed_range:
        await service.list_calendar(user_id, plant.id, today, today - timedelta(days=1), None)
    assert reversed_range.value.code == "INVALID_CALENDAR_RANGE"

    with pytest.raises(AppError) as too_wide:
        await service.list_calendar(user_id, plant.id, date(2026, 1, 1), date(2026, 4, 1), None)
    assert too_wide.value.code == "INVALID_CALENDAR_RANGE"


async def test_home_returns_empty_context_or_today_data() -> None:
    service, repository, _storage, user_id = build_service()
    repository.unread_count = 2
    repository.unread_letter_count = 3
    empty = await service.get_home(user_id, None)
    assert empty.plant is None
    assert empty.room is None
    assert empty.today_events == []
    assert empty.unread_letter_count == 3
    assert empty.unread_notification_count == 2

    plant = make_plant(user_id)
    repository.plants[plant.id] = plant
    repository.profile.selected_plant_id = plant.id
    today = today_in_timezone("Asia/Seoul")
    repository.events = [
        make_event(plant.id, today - timedelta(days=1)),
        make_event(plant.id, today),
    ]
    home = await service.get_home(user_id, None)

    assert home.plant is not None
    assert home.plant.started_on == plant.started_on
    assert home.plant.days_together == 11
    assert home.plant.personality_type.value == "OUTGOING"
    assert home.plant.body_id.value == "body_circle"
    assert home.plant.expression_id.value == "expression_default"
    assert home.room is not None
    assert home.room.dialogue_key.value == "NORMAL"
    assert home.room.dialogue is None
    assert [event.view_status.value for event in home.today_events] == ["TODAY"]
    assert "daily_memo" not in home.model_dump()


async def test_home_uses_selected_or_explicit_plant_and_rejects_unknown_plant() -> None:
    user_id = uuid4()
    first = make_plant(user_id, created_at=datetime.now(UTC) - timedelta(days=1))
    second = make_plant(user_id)
    service, repository, _storage, _ = build_service([first, second])
    repository.profile.selected_plant_id = second.id

    selected = await service.get_home(user_id, None)
    explicit = await service.get_home(user_id, first.id)

    assert selected.plant is not None and selected.plant.id == second.id
    assert explicit.plant is not None and explicit.plant.id == first.id

    with pytest.raises(AppError) as error:
        await service.get_home(user_id, uuid4())
    assert error.value.code == "PLANT_NOT_FOUND"

    repository.profile.selected_plant_id = uuid4()
    fallback = await service.get_home(user_id, None)
    assert fallback.plant is not None and fallback.plant.id == first.id


def test_home_days_start_at_one_and_background_changes_at_six_and_eighteen() -> None:
    today = today_in_timezone("Asia/Seoul")
    assert days_together(today, "Asia/Seoul") == 1
    assert home_background_phase(
        "UTC", now=datetime(2026, 1, 1, 5, 59, tzinfo=UTC)
    ).value == "NIGHT"
    assert home_background_phase(
        "UTC", now=datetime(2026, 1, 1, 6, 0, tzinfo=UTC)
    ).value == "DAY"
    assert home_background_phase(
        "UTC", now=datetime(2026, 1, 1, 17, 59, tzinfo=UTC)
    ).value == "DAY"
    assert home_background_phase(
        "UTC", now=datetime(2026, 1, 1, 18, 0, tzinfo=UTC)
    ).value == "NIGHT"


def test_home_route_returns_v2_contract(monkeypatch: pytest.MonkeyPatch) -> None:
    user_id = uuid4()
    plant = make_plant(user_id)
    service, repository, storage, _ = build_service([plant])
    repository.unread_count = 2
    repository.unread_letter_count = 3
    repository.events = [make_event(plant.id, today_in_timezone("Asia/Seoul"))]

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
    application.dependency_overrides[get_storage_gateway] = lambda: storage
    monkeypatch.setattr(
        plants_api,
        "build_management_service",
        lambda _session, _storage: service,
    )

    with TestClient(application) as client:
        response = client.get("/api/v1/home")

    assert response.status_code == 200
    payload = response.json()
    assert set(payload) == {
        "plant",
        "room",
        "today_events",
        "unread_letter_count",
        "unread_notification_count",
    }
    assert payload["plant"]["days_together"] == 11
    assert payload["room"]["dialogue_key"] == "NORMAL"
    assert payload["room"]["dialogue"] is None
    assert payload["today_events"][0]["care_type"] == "WATERING"
    assert payload["unread_letter_count"] == 3


async def test_delete_is_idempotent_and_selects_oldest_remaining_plant() -> None:
    user_id = uuid4()
    now = datetime.now(UTC)
    selected = make_plant(user_id, created_at=now)
    oldest = make_plant(user_id, created_at=now - timedelta(days=2))
    newest = make_plant(user_id, created_at=now - timedelta(days=1))
    service, repository, _storage, _ = build_service([selected, oldest, newest])
    repository.profile.selected_plant_id = selected.id

    first = await service.delete_plant(user_id, selected.id)
    second = await service.delete_plant(user_id, selected.id)

    assert first.enqueue_cleanup is True
    assert second.enqueue_cleanup is False
    assert repository.profile.selected_plant_id == oldest.id
    assert repository.marked_media_for == [selected.id]

    missing = await service.delete_plant(user_id, uuid4())
    assert missing.enqueue_cleanup is False


def test_delete_route_enqueues_cleanup_in_same_database_session(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    user_id = uuid4()
    plant_id = uuid4()
    session = object()

    class FakeDeleteService:
        async def delete_plant(self, actual_user_id: UUID, actual_plant_id: UUID):
            assert actual_user_id == user_id
            assert actual_plant_id == plant_id
            return DeletePlantResult(enqueue_cleanup=True)

    class FakeQueue:
        def __init__(self) -> None:
            self.calls: list[tuple[QueueJob, object]] = []

        async def enqueue(self, job: QueueJob, *, delay_seconds: int = 0, session=None) -> int:
            assert delay_seconds == 0
            self.calls.append((job, session))
            return 1

    def fake_session() -> Iterator[object]:
        yield session

    queue = FakeQueue()
    application = create_app()
    application.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=user_id,
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )
    application.dependency_overrides[get_database_session] = fake_session
    application.dependency_overrides[get_storage_gateway] = lambda: FakeStorage()
    application.dependency_overrides[get_job_queue] = lambda: queue
    monkeypatch.setattr(
        plants_api,
        "build_management_service",
        lambda _session, _storage: FakeDeleteService(),
    )

    with TestClient(application) as client:
        response = client.delete(f"/api/v1/plants/{plant_id}")

    assert response.status_code == 204
    assert len(queue.calls) == 1
    assert queue.calls[0][0].job_type == JobType.PLANT_DELETE
    assert queue.calls[0][0].resource_id == plant_id
    assert queue.calls[0][1] is session


def test_delete_route_skips_queue_when_plant_already_gone(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    user_id = uuid4()
    plant_id = uuid4()
    session = object()

    class FakeDeleteService:
        async def delete_plant(self, actual_user_id: UUID, actual_plant_id: UUID):
            assert actual_user_id == user_id
            assert actual_plant_id == plant_id
            return DeletePlantResult(enqueue_cleanup=False)

    class FakeQueue:
        def __init__(self) -> None:
            self.calls: list[QueueJob] = []

        async def enqueue(self, job: QueueJob, *, delay_seconds: int = 0, session=None) -> int:
            self.calls.append(job)
            return 1

    def fake_session() -> Iterator[object]:
        yield session

    queue = FakeQueue()
    application = create_app()
    application.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=user_id,
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )
    application.dependency_overrides[get_database_session] = fake_session
    application.dependency_overrides[get_storage_gateway] = lambda: FakeStorage()
    application.dependency_overrides[get_job_queue] = lambda: queue
    monkeypatch.setattr(
        plants_api,
        "build_management_service",
        lambda _session, _storage: FakeDeleteService(),
    )

    with TestClient(application) as client:
        response = client.delete(f"/api/v1/plants/{plant_id}")

    assert response.status_code == 204
    assert queue.calls == []


class FakeCleanupRepository:
    def __init__(self, paths: list[str]) -> None:
        self.paths = paths
        self.hard_deleted: list[UUID] = []

    async def list_media_paths(self, _plant_id: UUID) -> list[str]:
        return self.paths

    async def hard_delete(self, plant_id: UUID) -> None:
        self.hard_deleted.append(plant_id)


async def test_plant_delete_worker_deletes_storage_before_database() -> None:
    plant_id = uuid4()
    repository = FakeCleanupRepository(["plants/a.jpg", "diaries/b.jpg"])
    storage = FakeStorage()
    handler = PlantDeleteHandler(repository, storage)

    await handler(
        QueueJob(
            job_type=JobType.PLANT_DELETE,
            resource_id=plant_id,
            trace_id="req_plant_delete_test",
        )
    )

    assert storage.deleted == ["plants/a.jpg", "diaries/b.jpg"]
    assert repository.hard_deleted == [plant_id]


async def test_plant_delete_worker_keeps_database_when_storage_fails() -> None:
    class FailingStorage(FakeStorage):
        async def delete_object(self, _object_path: str) -> None:
            raise AppError(
                code="STORAGE_UNAVAILABLE",
                message="파일 저장소를 사용할 수 없습니다.",
                status_code=503,
            )

    plant_id = uuid4()
    repository = FakeCleanupRepository(["plants/a.jpg"])
    handler = PlantDeleteHandler(repository, FailingStorage())

    with pytest.raises(AppError):
        await handler(
            QueueJob(
                job_type=JobType.PLANT_DELETE,
                resource_id=plant_id,
                trace_id="req_plant_delete_failure",
            )
        )

    assert repository.hard_deleted == []
