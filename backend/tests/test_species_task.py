from uuid import uuid4

import pytest

from app.integrations.plantnet import PlantNetCandidate, PlantNetPermanentError
from app.models.enums import PlantCategory, WaterRecommendationSource
from app.models.plant import SpeciesCareGuide
from app.schemas.queue import JobType, QueueJob
from app.tasks.base import PermanentTaskError
from app.tasks.species import (
    IdentificationWork,
    SpeciesIdentificationHandler,
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

    async def start(self, _identification_id):
        return self.work

    async def find_guides(self, _candidates):
        return self.guides

    async def complete(self, identification_id, candidates):
        self.completed.append((identification_id, candidates))

    async def fail(self, identification_id, failure_code):
        self.failures.append((identification_id, failure_code))


class FakeStorage:
    async def download_object(self, object_path: str) -> bytes:
        assert object_path == "user/species/image.jpg"
        return b"\xff\xd8\xffimage"


class FakeProvider:
    def __init__(self, result=None, error: Exception | None = None) -> None:
        self.result = result or []
        self.error = error

    async def identify(self, image: bytes, content_type: str):
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
        water_recommendation_source=WaterRecommendationSource.SPECIES_GUIDE,
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
    assert candidates[0].confidence == 0.93


async def test_species_handler_prefers_gbif_match_over_scientific_name() -> None:
    repository = FakeRepository()
    guide = SpeciesCareGuide(
        species_reference_id="catalog:alocasia-mortfontanensis",
        display_name="알로카시아",
        scientific_name="Alocasia × mortfontanensis",
        gbif_id=5532250,
        category=PlantCategory.FOLIAGE,
        water_recommendation_source=WaterRecommendationSource.SPECIES_GUIDE,
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
