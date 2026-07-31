from datetime import UTC, datetime
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from app.api.v1.species import create_species_identification
from app.core.errors import AppError
from app.core.request_context import reset_request_id, set_request_id
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.enums import (
    MediaPurpose,
    MediaStatus,
    PlantCategory,
    SpeciesIdentificationStatus,
)
from app.models.media import MediaFile, SpeciesIdentification
from app.models.plant import SpeciesCareGuide
from app.schemas.queue import JobType, QueueJob
from app.schemas.species import SpeciesIdentificationCreateRequest
from app.services.species import SpeciesService, decode_cursor


class FakeSpeciesRepository:
    def __init__(self) -> None:
        self.guides: list[SpeciesCareGuide] = []
        self.media: dict[UUID, MediaFile] = {}
        self.identifications: dict[UUID, SpeciesIdentification] = {}

    async def search_guides(
        self,
        query: str,
        *,
        offset: int,
        limit: int,
    ) -> list[SpeciesCareGuide]:
        matches = [
            guide
            for guide in self.guides
            if query.casefold() in guide.display_name.casefold()
            or any(query.casefold() in alias.casefold() for alias in (guide.aliases or []))
            or (
                guide.scientific_name is not None
                and query.casefold() in guide.scientific_name.casefold()
            )
        ]
        return matches[offset : offset + limit]

    async def get_media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None:
        media_file = self.media.get(media_file_id)
        if media_file is None or media_file.user_id != user_id:
            return None
        return media_file

    async def get_identification_by_media_owned(
        self,
        media_file_id: UUID,
        user_id: UUID,
    ) -> SpeciesIdentification | None:
        return next(
            (
                identification
                for identification in self.identifications.values()
                if identification.media_file_id == media_file_id
                and identification.user_id == user_id
            ),
            None,
        )

    async def add_identification(self, identification: SpeciesIdentification) -> None:
        self.identifications[identification.id] = identification

    async def get_identification_owned(
        self,
        identification_id: UUID,
        user_id: UUID,
    ) -> SpeciesIdentification | None:
        identification = self.identifications.get(identification_id)
        if identification is None or identification.user_id != user_id:
            return None
        return identification


class FakeSpeciesSession:
    def __init__(self, media_file: MediaFile) -> None:
        self.media_file = media_file
        self.added: list[SpeciesIdentification] = []

    async def scalar(self, _statement):
        entity = _statement.column_descriptions[0].get("entity")
        if entity is MediaFile:
            return self.media_file
        if entity is SpeciesIdentification:
            return next(iter(self.added), None)
        raise AssertionError(f"Unexpected statement entity: {entity}")

    def add(self, item: SpeciesIdentification) -> None:
        self.added.append(item)

    async def flush(self) -> None:
        pass


class FakeQueue:
    def __init__(self) -> None:
        self.jobs: list[QueueJob] = []
        self.sessions: list[object] = []

    async def enqueue(self, job: QueueJob, *, delay_seconds: int = 0, session=None) -> int:
        self.jobs.append(job)
        self.sessions.append(session)
        return len(self.jobs)


def make_guide(index: int) -> SpeciesCareGuide:
    return SpeciesCareGuide(
        species_reference_id=f"catalog:basil-{index}",
        display_name=f"바질 {index}",
        scientific_name=f"Ocimum basilicum {index}",
        aliases=["스위트 바질"],
        category=PlantCategory.HERB,
        recommended_water_min_ml=150,
        recommended_water_max_ml=250,
        default_watering_interval_days=3,
        default_repotting_interval_days=365,
        active=True,
    )


def make_media(
    user_id: UUID,
    *,
    purpose: MediaPurpose = MediaPurpose.SPECIES_IDENTIFICATION,
    status: MediaStatus = MediaStatus.READY,
    content_type: str = "image/jpeg",
) -> MediaFile:
    return MediaFile(
        id=uuid4(),
        user_id=user_id,
        purpose=purpose,
        status=status,
        bucket_name="leafie-media",
        object_path=f"{user_id}/species-identification/{uuid4()}.jpg",
        content_type=content_type,
        size_bytes=1024,
    )


async def test_search_returns_shared_candidate_contract_and_cursor() -> None:
    repository = FakeSpeciesRepository()
    repository.guides = [make_guide(index) for index in range(3)]
    service = SpeciesService(repository)

    first = await service.search("바질", None, 2)
    second = await service.search("바질", first.next_cursor, 2)

    assert len(first.items) == 2
    assert first.has_next is True
    assert first.next_cursor is not None
    assert decode_cursor(first.next_cursor) == 2
    assert first.items[0].category_suggestion == PlantCategory.HERB
    assert first.items[0].recommended_water is not None
    assert first.items[0].recommended_water.min_ml == 150
    assert first.items[0].default_care is not None
    assert first.items[0].default_care.watering_interval_days == 3
    assert first.items[0].default_care.repotting_interval_days == 365
    assert [item.display_name for item in second.items] == ["바질 2"]
    assert second.has_next is False


async def test_search_matches_catalog_alias() -> None:
    repository = FakeSpeciesRepository()
    repository.guides = [make_guide(0)]

    result = await SpeciesService(repository).search("스위트", None, 20)

    assert [item.display_name for item in result.items] == ["바질 0"]


@pytest.mark.parametrize("query", ["", " ", "바"])
async def test_search_rejects_short_query(query: str) -> None:
    with pytest.raises(AppError) as error:
        await SpeciesService(FakeSpeciesRepository()).search(query, None, 20)

    assert error.value.code == "SPECIES_QUERY_TOO_SHORT"


async def test_create_identification_requires_owned_ready_species_media() -> None:
    user_id = uuid4()
    repository = FakeSpeciesRepository()
    service = SpeciesService(repository)

    with pytest.raises(AppError) as missing:
        await service.create_identification(user_id, uuid4())
    assert missing.value.code == "MEDIA_FILE_NOT_FOUND"

    wrong_purpose = make_media(user_id, purpose=MediaPurpose.DIAGNOSIS)
    repository.media[wrong_purpose.id] = wrong_purpose
    with pytest.raises(AppError) as purpose:
        await service.create_identification(user_id, wrong_purpose.id)
    assert purpose.value.code == "MEDIA_PURPOSE_MISMATCH"

    pending = make_media(user_id, status=MediaStatus.PENDING)
    repository.media[pending.id] = pending
    with pytest.raises(AppError) as status:
        await service.create_identification(user_id, pending.id)
    assert status.value.code == "MEDIA_NOT_READY"

    webp = make_media(user_id, content_type="image/webp")
    repository.media[webp.id] = webp
    with pytest.raises(AppError) as image_type:
        await service.create_identification(user_id, webp.id)
    assert image_type.value.code == "SPECIES_IMAGE_TYPE_UNSUPPORTED"


async def test_create_identification_rejects_other_users_media() -> None:
    owner_id = uuid4()
    requester_id = uuid4()
    repository = FakeSpeciesRepository()
    media_file = make_media(owner_id)
    repository.media[media_file.id] = media_file

    with pytest.raises(AppError) as error:
        await SpeciesService(repository).create_identification(
            requester_id,
            media_file.id,
        )

    assert error.value.code == "MEDIA_FILE_NOT_FOUND"
    assert repository.identifications == {}


async def test_create_identification_reuses_result_for_same_media() -> None:
    user_id = uuid4()
    repository = FakeSpeciesRepository()
    media_file = make_media(user_id)
    repository.media[media_file.id] = media_file
    service = SpeciesService(repository)

    first = await service.create_identification(user_id, media_file.id)
    second = await service.create_identification(user_id, media_file.id)

    assert first.created is True
    assert second.created is False
    assert second.response.id == first.response.id
    assert len(repository.identifications) == 1


async def test_create_and_get_identification() -> None:
    user_id = uuid4()
    repository = FakeSpeciesRepository()
    media_file = make_media(user_id)
    repository.media[media_file.id] = media_file
    service = SpeciesService(repository)

    creation = await service.create_identification(user_id, media_file.id)
    created = creation.response
    stored = repository.identifications[created.id]
    stored.status = SpeciesIdentificationStatus.COMPLETED
    stored.candidates = [
        {
            "reference_id": "plantnet:ocimum-basilicum",
            "display_name": "바질",
            "scientific_name": "Ocimum basilicum",
            "confidence": 0.91,
        }
    ]
    stored.completed_at = datetime.now(UTC)
    result = await service.get_identification(user_id, created.id)

    assert created.status == SpeciesIdentificationStatus.PENDING
    assert result.status == SpeciesIdentificationStatus.COMPLETED
    assert result.current_candidate_index == 0
    assert result.candidates[0].confidence == 0.91


async def test_create_route_enqueues_identification_in_same_session() -> None:
    user_id = uuid4()
    media_file = make_media(user_id)
    session = FakeSpeciesSession(media_file)
    queue = FakeQueue()
    current_user = AuthenticatedUser(
        id=user_id,
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )
    token = set_request_id("req_species_create")
    try:
        response = await create_species_identification(
            SpeciesIdentificationCreateRequest(media_file_id=media_file.id),
            current_user,
            session,
            queue,
        )
        duplicate_response = await create_species_identification(
            SpeciesIdentificationCreateRequest(media_file_id=media_file.id),
            current_user,
            session,
            queue,
        )
    finally:
        reset_request_id(token)

    assert len(session.added) == 1
    assert session.added[0].id == response.id
    assert duplicate_response.id == response.id
    assert queue.sessions == [session]
    assert queue.jobs == [
        QueueJob(
            job_type=JobType.SPECIES_IDENTIFICATION_RUN,
            resource_id=response.id,
            trace_id="req_species_create",
        )
    ]


def test_species_routes_require_authentication_before_database_access() -> None:
    application = create_app()

    with TestClient(application) as client:
        response = client.get("/api/v1/plant-species/search", params={"query": "바질"})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"
