from datetime import UTC, date, datetime
from uuid import UUID, uuid4

import pytest

from app.core.errors import AppError
from app.models.chat import AIConversation
from app.models.diagnosis import Diagnosis
from app.models.enums import DiagnosisStatus, MediaPurpose, MediaStatus
from app.models.media import MediaFile
from app.models.plant import Plant, SpeciesCareGuide
from app.schemas.diagnosis import DiagnosisCreateRequest
from app.services.diagnosis import (
    DiagnosisRecord,
    DiagnosisService,
    PlantDiagnosisContext,
)


class FakeRepository:
    def __init__(self, user_id: UUID, plant_id: UUID) -> None:
        self.user_id = user_id
        self.plant_id = plant_id
        self.plant = Plant(
            id=plant_id,
            user_id=user_id,
            species_reference_id="basil",
            nickname="새싹이",
            species_selection_method="SEARCH",
            started_on=date(2026, 7, 1),
            place_name="학교",
            pot_type="PLASTIC",
            placement="WINDOW",
            personality_type="OUTGOING",
            color_id="green",
            hair_id="basil",
            accessory_id="none",
        )
        self.guide = SpeciesCareGuide(
            species_reference_id="basil",
            display_name="바질",
            scientific_name="Ocimum basilicum",
            category="HERB",
            diagnosis_profile={},
        )
        self.conversation = AIConversation(
            id=uuid4(),
            plant_id=plant_id,
            title="바질 상담",
        )
        self.media = MediaFile(
            id=uuid4(),
            user_id=user_id,
            purpose=MediaPurpose.DIAGNOSIS.value,
            status=MediaStatus.READY.value,
            bucket_name="leafie-media",
            object_path=f"{user_id}/diagnosis/photo.jpg",
            content_type="image/jpeg",
        )
        self.diagnoses: list[Diagnosis] = []

    async def plant_context_owned(self, plant_id: UUID, user_id: UUID):
        if (plant_id, user_id) != (self.plant_id, self.user_id):
            return None
        return PlantDiagnosisContext(self.plant, self.guide, "2026-07-30", None)

    async def conversation_owned(self, conversation_id: UUID, user_id: UUID):
        if conversation_id == self.conversation.id and user_id == self.user_id:
            return self.conversation
        return None

    async def media_owned(self, media_file_id: UUID, user_id: UUID):
        if media_file_id == self.media.id and user_id == self.user_id:
            return self.media
        return None

    async def diagnosis_by_media_owned(self, media_file_id: UUID, user_id: UUID):
        return next(
            (
                item
                for item in self.diagnoses
                if item.media_file_id == media_file_id and user_id == self.user_id
            ),
            None,
        )

    async def add(self, diagnosis: Diagnosis) -> Diagnosis:
        self.diagnoses.append(diagnosis)
        return diagnosis

    async def list_owned(self, plant_id: UUID, user_id: UUID, offset: int, limit: int):
        if (plant_id, user_id) != (self.plant_id, self.user_id):
            return []
        return [
            DiagnosisRecord(item, self.media.object_path)
            for item in self.diagnoses[offset : offset + limit]
        ]

    async def get_owned(self, diagnosis_id: UUID, user_id: UUID, *, lock: bool = False):
        del lock
        if user_id != self.user_id:
            return None
        item = next((item for item in self.diagnoses if item.id == diagnosis_id), None)
        return DiagnosisRecord(item, self.media.object_path) if item else None


class FakeStorage:
    async def create_signed_download_url(self, object_path: str, *, expires_in: int) -> str:
        return f"https://storage.test/{object_path}?expires={expires_in}"


def _service(repository: FakeRepository, *, configured: bool = True) -> DiagnosisService:
    return DiagnosisService(
        repository,
        FakeStorage(),
        provider_configured=configured,
        download_url_expires_seconds=300,
    )


async def test_create_diagnosis_is_idempotent_for_same_photo() -> None:
    user_id = uuid4()
    plant_id = uuid4()
    repository = FakeRepository(user_id, plant_id)
    request = DiagnosisCreateRequest(
        conversation_id=repository.conversation.id,
        media_file_id=repository.media.id,
    )

    first, first_created = await _service(repository).create(user_id, plant_id, request)
    second, second_created = await _service(repository).create(user_id, plant_id, request)

    assert first_created is True
    assert second_created is False
    assert first.diagnosis_id == second.diagnosis_id
    assert repository.diagnoses[0].input_context_snapshot["species_name"] == "바질"


async def test_create_diagnosis_rejects_wrong_media_purpose() -> None:
    user_id = uuid4()
    plant_id = uuid4()
    repository = FakeRepository(user_id, plant_id)
    repository.media.purpose = MediaPurpose.DIARY.value
    request = DiagnosisCreateRequest(
        conversation_id=repository.conversation.id,
        media_file_id=repository.media.id,
    )

    with pytest.raises(AppError) as error:
        await _service(repository).create(user_id, plant_id, request)

    assert error.value.code == "MEDIA_PURPOSE_MISMATCH"


async def test_create_diagnosis_requires_configured_provider() -> None:
    user_id = uuid4()
    plant_id = uuid4()
    repository = FakeRepository(user_id, plant_id)
    request = DiagnosisCreateRequest(
        conversation_id=repository.conversation.id,
        media_file_id=repository.media.id,
    )

    with pytest.raises(AppError) as error:
        await _service(repository, configured=False).create(user_id, plant_id, request)

    assert error.value.code == "DIAGNOSIS_PROVIDER_NOT_CONFIGURED"


async def test_retry_only_allows_retryable_failures() -> None:
    user_id = uuid4()
    plant_id = uuid4()
    repository = FakeRepository(user_id, plant_id)
    diagnosis = Diagnosis(
        id=uuid4(),
        plant_id=plant_id,
        related_conversation_id=repository.conversation.id,
        media_file_id=repository.media.id,
        status=DiagnosisStatus.FAILED.value,
        failure_code="DIAGNOSIS_PROVIDER_UNAVAILABLE",
        created_at=datetime.now(UTC),
    )
    repository.diagnoses.append(diagnosis)

    response = await _service(repository).retry(user_id, diagnosis.id)

    assert response.status == DiagnosisStatus.PENDING
    assert diagnosis.failure_code is None


async def test_diagnosis_detail_rejects_another_user() -> None:
    user_id = uuid4()
    plant_id = uuid4()
    repository = FakeRepository(user_id, plant_id)
    diagnosis = Diagnosis(
        id=uuid4(),
        plant_id=plant_id,
        media_file_id=repository.media.id,
        status=DiagnosisStatus.COMPLETED.value,
        created_at=datetime.now(UTC),
    )
    repository.diagnoses.append(diagnosis)

    with pytest.raises(AppError) as error:
        await _service(repository).get(uuid4(), diagnosis.id)

    assert error.value.code == "DIAGNOSIS_NOT_FOUND"
