from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.dependencies import get_current_user, get_database_session
from app.api.v1 import plants as plants_api
from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.care import CareEvent, CareSchedule
from app.models.chat import AIConversation
from app.models.enums import (
    CareEventStatus,
    CareEventType,
    CareScheduleType,
    MediaPurpose,
    MediaStatus,
    PlantCategory,
    RepottingHistoryStatus,
    SpeciesIdentificationStatus,
)
from app.models.media import MediaFile, SpeciesIdentification
from app.models.plant import Plant, SpeciesCareGuide
from app.models.user import UserProfile
from app.schemas.plant import PlantCreateRequest
from app.services.plant import PlantRegistrationService


class FakePlantRegistrationRepository:
    def __init__(self, user_id: UUID) -> None:
        self.profile: UserProfile | None = UserProfile(
            user_id=user_id,
            nickname="초록집사",
            timezone="Asia/Seoul",
            profile_completed_at=datetime.now(UTC),
        )
        self.guides: dict[str, SpeciesCareGuide] = {}
        self.identifications: dict[UUID, SpeciesIdentification] = {}
        self.media: dict[UUID, MediaFile] = {}
        self.used_identifications: set[UUID] = set()
        self.added: list[object] = []
        self.added_batches: list[tuple[object, ...]] = []
        self.flush_count = 0

    async def get_profile_for_update(self, user_id: UUID) -> UserProfile | None:
        if self.profile is None or self.profile.user_id != user_id:
            return None
        return self.profile

    async def get_active_guide(self, species_reference_id: str) -> SpeciesCareGuide | None:
        guide = self.guides.get(species_reference_id)
        if guide is None or not guide.active:
            return None
        return guide

    async def get_identification_for_update(
        self, identification_id: UUID, user_id: UUID
    ) -> SpeciesIdentification | None:
        identification = self.identifications.get(identification_id)
        if identification is None or identification.user_id != user_id:
            return None
        return identification

    async def identification_is_used(self, identification_id: UUID) -> bool:
        return identification_id in self.used_identifications

    async def get_media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None:
        media_file = self.media.get(media_file_id)
        if (
            media_file is None
            or media_file.user_id != user_id
            or media_file.deleted_at is not None
        ):
            return None
        return media_file

    async def add_registration(self, *entities: object) -> None:
        self.added_batches.append(entities)
        self.added.extend(entities)

    async def flush(self) -> None:
        self.flush_count += 1


def make_guide() -> SpeciesCareGuide:
    return SpeciesCareGuide(
        species_reference_id="catalog:ocimum-basilicum",
        display_name="바질",
        scientific_name="Ocimum basilicum",
        aliases=["스위트 바질"],
        category=PlantCategory.HERB.value,
        recommended_water_min_ml=150,
        recommended_water_max_ml=250,
        default_watering_interval_days=3,
        default_repotting_interval_days=365,
        active=True,
    )


def make_request(**overrides: object) -> PlantCreateRequest:
    payload: dict[str, object] = {
        "nickname": "새싹이",
        "species_reference_id": "catalog:ocimum-basilicum",
        "species_selection_method": "SEARCH",
        "species_identification_id": None,
        "primary_media_file_id": None,
        "started_on": "2026-03-01",
        "place_name": "학교",
        "pot_type": "PLASTIC",
        "placement": "WINDOW",
        "last_watered_on": "2026-07-30",
        "repotting_history": {"status": "KNOWN", "date": "2026-03-01"},
        "personality_type": "OUTGOING",
        "color_id": "color_green_01",
        "hair_id": "hair_leaf_01",
        "accessory_id": "accessory_star_01",
    }
    payload.update(overrides)
    return PlantCreateRequest.model_validate(payload)


def make_photo_registration(
    user_id: UUID,
) -> tuple[PlantCreateRequest, SpeciesIdentification, MediaFile]:
    media_file = MediaFile(
        id=uuid4(),
        user_id=user_id,
        purpose=MediaPurpose.SPECIES_IDENTIFICATION.value,
        status=MediaStatus.READY.value,
        bucket_name="leafie-media",
        object_path=f"{user_id}/species-identification/{uuid4()}.jpg",
        content_type="image/jpeg",
        size_bytes=1024,
    )
    identification = SpeciesIdentification(
        id=uuid4(),
        user_id=user_id,
        media_file_id=media_file.id,
        status=SpeciesIdentificationStatus.COMPLETED.value,
        candidates=[
            {
                "reference_id": "catalog:ocimum-basilicum",
                "display_name": "바질",
                "confidence": 0.91,
            }
        ],
    )
    request = make_request(
        species_selection_method="PHOTO",
        species_identification_id=identification.id,
        primary_media_file_id=media_file.id,
    )
    return request, identification, media_file


def build_service() -> tuple[PlantRegistrationService, FakePlantRegistrationRepository, UUID]:
    user_id = uuid4()
    repository = FakePlantRegistrationRepository(user_id)
    guide = make_guide()
    repository.guides[guide.species_reference_id] = guide
    return PlantRegistrationService(repository), repository, user_id


async def test_search_registration_creates_flat_plant_and_initial_resources() -> None:
    service, repository, user_id = build_service()

    response = await service.create_plant(user_id, make_request())

    plant = next(entity for entity in repository.added if isinstance(entity, Plant))
    schedule = next(entity for entity in repository.added if isinstance(entity, CareSchedule))
    events = [entity for entity in repository.added if isinstance(entity, CareEvent)]
    conversation = next(
        entity for entity in repository.added if isinstance(entity, AIConversation)
    )

    assert response.id == plant.id
    assert response.created_at == plant.created_at
    assert plant.user_id == user_id
    assert plant.species_identification_id is None
    assert plant.primary_media_file_id is None
    assert plant.place_name == "학교"
    assert plant.personality_type == "OUTGOING"
    assert repository.profile is not None
    assert repository.profile.selected_plant_id == plant.id
    assert repository.flush_count == 1

    assert schedule.type == CareScheduleType.WATERING
    assert schedule.interval_days == 3
    assert schedule.next_due_date == date(2026, 8, 2)
    assert schedule.recommended_water_min_ml == 150
    assert schedule.recommended_water_max_ml == 250

    assert {event.type for event in events} == {
        CareEventType.WATERING,
        CareEventType.REPOTTING,
    }
    assert all(event.status == CareEventStatus.COMPLETED for event in events)
    repotting_event = next(event for event in events if event.type == CareEventType.REPOTTING)
    assert repotting_event.schedule_id is None
    assert repotting_event.performed_on == date(2026, 3, 1)
    assert conversation.plant_id == plant.id
    assert conversation.title == "새 채팅"
    assert [[type(entity) for entity in batch] for batch in repository.added_batches] == [
        [Plant],
        [CareSchedule, AIConversation],
        [CareEvent, CareEvent],
    ]


@pytest.mark.parametrize(
    "repotting_history",
    [
        {"status": RepottingHistoryStatus.NEVER.value, "date": None},
        {"status": RepottingHistoryStatus.UNKNOWN.value, "date": None},
    ],
)
async def test_registration_without_known_repotting_date_does_not_create_repotting_event(
    repotting_history: dict[str, object],
) -> None:
    service, repository, user_id = build_service()

    await service.create_plant(user_id, make_request(repotting_history=repotting_history))

    events = [entity for entity in repository.added if isinstance(entity, CareEvent)]
    assert [event.type for event in events] == [CareEventType.WATERING]
    schedules = [entity for entity in repository.added if isinstance(entity, CareSchedule)]
    assert [schedule.type for schedule in schedules] == [CareScheduleType.WATERING]


async def test_photo_registration_reuses_completed_identification_image() -> None:
    service, repository, user_id = build_service()
    request, identification, media_file = make_photo_registration(user_id)
    repository.identifications[identification.id] = identification
    repository.media[media_file.id] = media_file

    await service.create_plant(user_id, request)

    plant = next(entity for entity in repository.added if isinstance(entity, Plant))
    assert plant.species_identification_id == identification.id
    assert plant.primary_media_file_id == media_file.id


@pytest.mark.parametrize(
    "payload",
    [
        {"species_selection_method": "PHOTO"},
        {
            "species_selection_method": "SEARCH",
            "species_identification_id": uuid4(),
        },
        {"color_id": "   "},
        {"repotting_history": {"status": "KNOWN", "date": None}},
        {"repotting_history": {"status": "NEVER", "date": "2026-03-01"}},
        {"unexpected": "value"},
    ],
)
def test_registration_schema_rejects_invalid_combinations(payload: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        make_request(**payload)


@pytest.mark.parametrize(
    ("configure", "error_code"),
    [
        ("missing", "SPECIES_IDENTIFICATION_NOT_FOUND"),
        ("pending", "SPECIES_IDENTIFICATION_NOT_COMPLETED"),
        ("used", "SPECIES_IDENTIFICATION_ALREADY_USED"),
        ("candidate", "SPECIES_CANDIDATE_MISMATCH"),
        ("media_mismatch", "SPECIES_IDENTIFICATION_MEDIA_MISMATCH"),
        ("media_missing", "MEDIA_FILE_NOT_FOUND"),
        ("media_purpose", "MEDIA_PURPOSE_MISMATCH"),
        ("media_pending", "MEDIA_NOT_READY"),
    ],
)
async def test_photo_registration_validates_identification_and_media(
    configure: str,
    error_code: str,
) -> None:
    service, repository, user_id = build_service()
    request, identification, media_file = make_photo_registration(user_id)

    if configure != "missing":
        repository.identifications[identification.id] = identification
    if configure not in {"missing", "media_missing"}:
        repository.media[media_file.id] = media_file
    if configure == "pending":
        identification.status = SpeciesIdentificationStatus.PENDING.value
    elif configure == "used":
        repository.used_identifications.add(identification.id)
    elif configure == "candidate":
        identification.candidates = [{"reference_id": "catalog:different"}]
    elif configure == "media_mismatch":
        request.primary_media_file_id = uuid4()
    elif configure == "media_purpose":
        media_file.purpose = MediaPurpose.DIAGNOSIS.value
    elif configure == "media_pending":
        media_file.status = MediaStatus.PENDING.value

    with pytest.raises(AppError) as error:
        await service.create_plant(user_id, request)

    assert error.value.code == error_code
    assert repository.added == []


@pytest.mark.parametrize("field", ["started_on", "last_watered_on"])
async def test_registration_rejects_future_dates(field: str) -> None:
    service, repository, user_id = build_service()
    tomorrow = datetime.now(ZoneInfo("Asia/Seoul")).date() + timedelta(days=1)

    with pytest.raises(AppError) as error:
        await service.create_plant(user_id, make_request(**{field: tomorrow}))

    assert error.value.code == "FUTURE_DATE_NOT_ALLOWED"
    assert repository.added == []


async def test_registration_rejects_future_known_repotting_date() -> None:
    service, repository, user_id = build_service()
    tomorrow = datetime.now(ZoneInfo("Asia/Seoul")).date() + timedelta(days=1)

    with pytest.raises(AppError) as error:
        await service.create_plant(
            user_id,
            make_request(repotting_history={"status": "KNOWN", "date": tomorrow}),
        )

    assert error.value.code == "FUTURE_DATE_NOT_ALLOWED"
    assert repository.added == []


async def test_registration_requires_profile_supported_species_and_watering_guide() -> None:
    service, repository, user_id = build_service()
    repository.profile = None
    with pytest.raises(AppError) as profile_error:
        await service.create_plant(user_id, make_request())
    assert profile_error.value.code == "USER_PROFILE_NOT_FOUND"

    repository.profile = UserProfile(
        user_id=user_id,
        nickname="초록집사",
        timezone="Asia/Seoul",
        profile_completed_at=None,
    )
    with pytest.raises(AppError) as incomplete_error:
        await service.create_plant(user_id, make_request())
    assert incomplete_error.value.code == "PROFILE_INCOMPLETE"

    repository.profile.profile_completed_at = datetime.now(UTC)
    repository.guides.clear()
    with pytest.raises(AppError) as species_error:
        await service.create_plant(user_id, make_request())
    assert species_error.value.code == "SPECIES_NOT_FOUND"

    guide = make_guide()
    guide.default_watering_interval_days = None
    repository.guides[guide.species_reference_id] = guide
    with pytest.raises(AppError) as guide_error:
        await service.create_plant(user_id, make_request())
    assert guide_error.value.code == "SPECIES_CARE_GUIDE_INCOMPLETE"


def test_plant_registration_route_requires_authentication() -> None:
    application = create_app()

    with TestClient(application) as client:
        response = client.post("/api/v1/plants", json=make_request().model_dump(mode="json"))

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"


def test_plant_registration_route_returns_documented_created_response(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    service, repository, user_id = build_service()

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
    monkeypatch.setattr(plants_api, "build_service", lambda _session: service)

    with TestClient(application) as client:
        response = client.post("/api/v1/plants", json=make_request().model_dump(mode="json"))

    plant = next(entity for entity in repository.added if isinstance(entity, Plant))
    assert response.status_code == 201
    assert response.json()["id"] == str(plant.id)
    assert response.json()["created_at"] == plant.created_at.isoformat().replace("+00:00", "Z")


def test_photo_registration_succeeds_through_http_api(monkeypatch: pytest.MonkeyPatch) -> None:
    service, repository, user_id = build_service()
    request, identification, media_file = make_photo_registration(user_id)
    repository.identifications[identification.id] = identification
    repository.media[media_file.id] = media_file

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
    monkeypatch.setattr(plants_api, "build_service", lambda _session: service)

    with TestClient(application) as client:
        response = client.post("/api/v1/plants", json=request.model_dump(mode="json"))

    plant = next(entity for entity in repository.added if isinstance(entity, Plant))
    assert response.status_code == 201
    assert response.json()["id"] == str(plant.id)
    assert plant.species_identification_id == identification.id
    assert plant.primary_media_file_id == media_file.id


@pytest.mark.parametrize(
    "invalid_payload",
    [
        {
            "species_selection_method": "PHOTO",
            "species_identification_id": None,
            "primary_media_file_id": None,
        },
        {
            "species_selection_method": "SEARCH",
            "species_identification_id": str(uuid4()),
            "primary_media_file_id": str(uuid4()),
        },
    ],
)
def test_registration_http_api_rejects_invalid_selection_payload(
    invalid_payload: dict[str, object],
) -> None:
    payload = make_request().model_dump(mode="json")
    payload.update(invalid_payload)
    application = create_app()
    application.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=uuid4(),
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )

    def fake_session() -> Iterator[object]:
        yield object()

    application.dependency_overrides[get_database_session] = fake_session

    with TestClient(application) as client:
        response = client.post("/api/v1/plants", json=payload)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
