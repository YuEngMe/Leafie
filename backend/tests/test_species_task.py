from uuid import uuid4

import pytest

from app.core.errors import AppError
from app.integrations.plantnet import (
    PlantNetCandidate,
    PlantNetPermanentError,
    PlantNetTransientError,
)
from app.models.enums import PlantCategory
from app.models.plant import SpeciesCareGuide
from app.schemas.queue import JobType, QueueJob
from app.tasks.base import PermanentTaskError
from app.tasks.species import (
    IdentificationWork,
    SpeciesIdentificationHandler,
    SpeciesIdentificationInProgressError,
    find_matching_guide,
)


class FakeRepository:
    def __init__(self) -> None:
        self.work: IdentificationWork | None = IdentificationWork(
            object_path="user/species/image.jpg",
            content_type="image/jpeg",
        )
        self.guides: dict[str, SpeciesCareGuide] = {}
        self.completed = []
        self.failures: list[tuple[object, str]] = []
        self.released: list[object] = []
        self.started: set[object] = set()
        self.start_error: Exception | None = None

    async def start(self, identification_id):
        if self.start_error is not None:
            raise self.start_error
        if identification_id in self.started:
            return None
        self.started.add(identification_id)
        return self.work

    async def find_guides(self, _candidates):
        return self.guides

    async def complete(self, identification_id, candidates):
        self.completed.append((identification_id, candidates))

    async def release_for_retry(self, identification_id):
        self.released.append(identification_id)
        self.started.discard(identification_id)

    async def fail(self, identification_id, failure_code):
        self.failures.append((identification_id, failure_code))


class FakeStorage:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error

    async def download_object(self, object_path: str) -> bytes:
        assert object_path == "user/species/image.jpg"
        if self.error is not None:
            raise self.error
        return b"\xff\xd8\xffimage"


class FakeProvider:
    def __init__(self, result=None, error: Exception | None = None) -> None:
        self.result = result or []
        self.error = error
        self.calls = 0

    async def identify(self, image: bytes, content_type: str):
        self.calls += 1
        assert image == b"\xff\xd8\xffimage"
        assert content_type == "image/jpeg"
        if self.error:
            raise self.error
        return self.result


def make_job() -> QueueJob:
    return QueueJob(
        job_type=JobType.SPECIES_IDENTIFICATION_RUN,
        resource_id=uuid4(),
        trace_id="req_species_task",
    )


async def test_species_handler_applies_catalog_metadata() -> None:
    repository = FakeRepository()
    guide = SpeciesCareGuide(
        species_reference_id="catalog:ocimum-basilicum",
        display_name="바질",
        scientific_name="Ocimum basilicum",
        category=PlantCategory.HERB,
        recommended_water_min_ml=150,
        recommended_water_max_ml=250,
        default_watering_interval_days=3,
        default_repotting_interval_days=365,
        active=True,
    )
    repository.guides = {
        "gbif:2927096": guide,
        "name:ocimum basilicum": guide,
    }
    provider = FakeProvider(
        [
            PlantNetCandidate(
                scientific_name="Ocimum basilicum",
                common_names=("Sweet basil",),
                confidence=0.93,
                gbif_id=2927096,
            )
        ]
    )
    job = make_job()

    await SpeciesIdentificationHandler(repository, FakeStorage(), provider)(job)

    _, candidates = repository.completed[0]
    assert candidates[0].reference_id == "catalog:ocimum-basilicum"
    assert candidates[0].display_name == "바질"
    assert candidates[0].category_suggestion == PlantCategory.HERB
    assert candidates[0].recommended_water.min_ml == 150
    assert candidates[0].default_care is not None
    assert candidates[0].default_care.watering_interval_days == 3
    assert candidates[0].default_care.repotting_interval_days == 365
    assert candidates[0].confidence == 0.93


async def test_species_handler_prefers_gbif_match_over_scientific_name() -> None:
    repository = FakeRepository()
    guide = SpeciesCareGuide(
        species_reference_id="catalog:alocasia-mortfontanensis",
        display_name="알로카시아",
        scientific_name="Alocasia × mortfontanensis",
        gbif_id=5532250,
        category=PlantCategory.FOLIAGE,
        active=True,
    )
    repository.guides = {"gbif:5532250": guide}
    provider = FakeProvider(
        [
            PlantNetCandidate(
                scientific_name="Alocasia mortfontanensis",
                common_names=("African mask plant",),
                confidence=0.88,
                gbif_id=5532250,
            )
        ]
    )

    await SpeciesIdentificationHandler(repository, FakeStorage(), provider)(make_job())

    assert repository.completed[0][1][0].reference_id == guide.species_reference_id


async def test_species_handler_marks_permanent_provider_failure() -> None:
    repository = FakeRepository()
    provider = FakeProvider(error=PlantNetPermanentError("PLANTNET_AUTH_FAILED"))
    job = make_job()

    with pytest.raises(PermanentTaskError):
        await SpeciesIdentificationHandler(repository, FakeStorage(), provider)(job)

    assert repository.failures == [(job.resource_id, "PLANTNET_AUTH_FAILED")]


async def test_species_handler_marks_empty_candidates_as_failed() -> None:
    repository = FakeRepository()
    provider = FakeProvider([])
    job = make_job()

    await SpeciesIdentificationHandler(repository, FakeStorage(), provider)(job)

    assert repository.failures == [(job.resource_id, "SPECIES_NO_CANDIDATES")]
    assert repository.released == []
    assert repository.completed == []


async def test_species_handler_releases_transient_failure_for_retry() -> None:
    repository = FakeRepository()
    provider = FakeProvider(error=PlantNetTransientError("temporary"))
    handler = SpeciesIdentificationHandler(repository, FakeStorage(), provider)
    job = make_job()

    with pytest.raises(PlantNetTransientError):
        await handler(job)

    assert repository.released == [job.resource_id]

    provider.error = None
    provider.result = [
        PlantNetCandidate(
            scientific_name="Ocimum basilicum",
            common_names=("Sweet basil",),
            confidence=0.93,
        )
    ]
    await handler(job)

    assert provider.calls == 2
    assert len(repository.completed) == 1


async def test_species_handler_releases_storage_outage_for_retry() -> None:
    repository = FakeRepository()
    storage = FakeStorage(
        AppError(
            code="STORAGE_UNAVAILABLE",
            message="저장소를 사용할 수 없습니다.",
            status_code=503,
        )
    )
    job = make_job()

    with pytest.raises(AppError) as error:
        await SpeciesIdentificationHandler(repository, storage, FakeProvider())(job)

    assert error.value.code == "STORAGE_UNAVAILABLE"
    assert repository.released == [job.resource_id]


async def test_species_handler_marks_missing_uploaded_media_as_permanent() -> None:
    repository = FakeRepository()
    storage = FakeStorage(
        AppError(
            code="MEDIA_UPLOAD_NOT_FOUND",
            message="업로드 파일이 없습니다.",
            status_code=404,
        )
    )
    job = make_job()

    with pytest.raises(PermanentTaskError) as error:
        await SpeciesIdentificationHandler(repository, storage, FakeProvider())(job)

    assert error.value.failure_code == "MEDIA_UPLOAD_NOT_FOUND"
    assert repository.failures == [(job.resource_id, "MEDIA_UPLOAD_NOT_FOUND")]


async def test_species_handler_ignores_duplicate_message_delivery() -> None:
    repository = FakeRepository()
    provider = FakeProvider(
        [
            PlantNetCandidate(
                scientific_name="Ocimum basilicum",
                common_names=("Sweet basil",),
                confidence=0.93,
            )
        ]
    )
    handler = SpeciesIdentificationHandler(repository, FakeStorage(), provider)
    job = make_job()

    await handler(job)
    await handler(job)

    assert provider.calls == 1
    assert len(repository.completed) == 1


async def test_species_handler_retries_duplicate_processing_delivery() -> None:
    repository = FakeRepository()
    repository.start_error = SpeciesIdentificationInProgressError(
        "식물 인식 작업이 이미 처리 중입니다."
    )
    provider = FakeProvider()

    with pytest.raises(SpeciesIdentificationInProgressError):
        await SpeciesIdentificationHandler(repository, FakeStorage(), provider)(make_job())

    assert provider.calls == 0


def test_species_candidate_matches_catalog_alias_case_insensitively() -> None:
    guide = SpeciesCareGuide(
        species_reference_id="catalog:dracaena-trifasciata",
        display_name="산세베리아",
        scientific_name="Dracaena trifasciata",
        aliases=["Snake Plant", "Sansevieria trifasciata"],
        category=PlantCategory.FOLIAGE,
        active=True,
    )
    guides = {
        "alias:snake plant": guide,
        "alias:sansevieria trifasciata": guide,
    }

    former_name = PlantNetCandidate(
        scientific_name="Sansevieria trifasciata",
        common_names=(),
        confidence=0.8,
    )
    common_name = PlantNetCandidate(
        scientific_name="Dracaena sp.",
        common_names=("SNAKE PLANT",),
        confidence=0.7,
    )

    assert find_matching_guide(former_name, guides) is guide
    assert find_matching_guide(common_name, guides) is guide


async def test_species_handler_marks_no_candidate_and_exhaustion() -> None:
    repository = FakeRepository()
    handler = SpeciesIdentificationHandler(repository, FakeStorage(), FakeProvider())
    job = make_job()

    await handler(job)
    await handler.on_exhausted(job)

    assert repository.failures == [
        (job.resource_id, "SPECIES_NO_CANDIDATES"),
        (job.resource_id, "SPECIES_PROVIDER_UNAVAILABLE"),
    ]
