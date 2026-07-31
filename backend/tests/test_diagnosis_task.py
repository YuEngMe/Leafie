from uuid import uuid4

import pytest

from app.core.errors import AppError
from app.integrations.diagnosis import (
    DiagnosisImageQualityResult,
    DiagnosisPermanentError,
    DiagnosisProviderResult,
    DiagnosisTransientError,
)
from app.schemas.queue import JobType, QueueJob
from app.tasks.base import PermanentTaskError
from app.tasks.diagnosis import DiagnosisHandler, DiagnosisWork


class FakeRepository:
    def __init__(self) -> None:
        self.work: DiagnosisWork | None = DiagnosisWork(
            object_path="user/diagnosis/image.jpg",
            content_type="image/jpeg",
            input_context={"species_name": "바질"},
        )
        self.completed: list[tuple] = []
        self.retake: list[tuple] = []
        self.released: list = []
        self.failed: list[tuple] = []

    async def start(self, _diagnosis_id):
        return self.work

    async def complete(self, diagnosis_id, quality, result, recommended_care):
        self.completed.append((diagnosis_id, quality, result, recommended_care))

    async def needs_retake(self, diagnosis_id, quality):
        self.retake.append((diagnosis_id, quality))

    async def release_for_retry(self, diagnosis_id):
        self.released.append(diagnosis_id)

    async def fail(self, diagnosis_id, failure_code):
        self.failed.append((diagnosis_id, failure_code))


class FakeStorage:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error

    async def download_object(self, object_path: str) -> bytes:
        assert object_path == "user/diagnosis/image.jpg"
        if self.error:
            raise self.error
        return b"image"


class FakeQualityChecker:
    def __init__(self, result: DiagnosisImageQualityResult) -> None:
        self.result = result

    async def check(self, image: bytes, content_type: str) -> DiagnosisImageQualityResult:
        assert image == b"image"
        assert content_type == "image/jpeg"
        return self.result


class FakeProvider:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error
        self.calls = 0

    async def diagnose(self, image: bytes, content_type: str, context: dict):
        self.calls += 1
        assert image == b"image"
        assert content_type == "image/jpeg"
        assert context == {"species_name": "바질"}
        if self.error:
            raise self.error
        return DiagnosisProviderResult(
            overall_condition="UNHEALTHY",
            condition_label="조금 관리가 필요해요",
            observations=["잎 끝 마름"],
            possible_causes=[{"name": "물 부족", "confidence": 0.76}],
            provider_name="fake",
            model_name="fake-v1",
        )


def accepted_quality() -> DiagnosisImageQualityResult:
    return DiagnosisImageQualityResult(
        acceptable=True,
        plant_visible=True,
        sharp_enough=True,
        brightness_acceptable=True,
        symptom_area_visible=True,
    )


def make_job() -> QueueJob:
    return QueueJob(
        job_type=JobType.DIAGNOSIS_RUN,
        resource_id=uuid4(),
        trace_id="req_diagnosis",
    )


def build_handler(
    repository: FakeRepository,
    *,
    quality: DiagnosisImageQualityResult | None = None,
    provider: FakeProvider | None = None,
    storage: FakeStorage | None = None,
) -> DiagnosisHandler:
    return DiagnosisHandler(
        repository,
        storage or FakeStorage(),
        FakeQualityChecker(quality or accepted_quality()),
        provider or FakeProvider(),
        lambda _result, _context: [" 흙 상태를 확인한 뒤 물을 주세요. "],
    )


async def test_diagnosis_handler_completes_normalized_result() -> None:
    repository = FakeRepository()
    job = make_job()

    await build_handler(repository)(job)

    assert repository.completed[0][0] == job.resource_id
    assert repository.completed[0][2].possible_causes[0].confidence == 0.76
    assert repository.completed[0][3] == ["흙 상태를 확인한 뒤 물을 주세요."]
    assert repository.retake == []
    assert repository.released == []
    assert repository.failed == []


async def test_diagnosis_handler_marks_low_quality_image_for_retake() -> None:
    repository = FakeRepository()
    provider = FakeProvider()
    quality = accepted_quality().model_copy(
        update={"acceptable": False, "sharp_enough": False, "retake_reason_code": "IMAGE_BLURRY"}
    )
    job = make_job()

    await build_handler(repository, quality=quality, provider=provider)(job)

    assert repository.retake[0][0] == job.resource_id
    assert repository.retake[0][1].retake_reason_code == "IMAGE_BLURRY"
    assert provider.calls == 0
    assert repository.completed == []


async def test_diagnosis_handler_marks_permanent_provider_failure() -> None:
    repository = FakeRepository()
    provider = FakeProvider(DiagnosisPermanentError("DIAGNOSIS_PROVIDER_AUTH_FAILED"))
    job = make_job()

    with pytest.raises(PermanentTaskError):
        await build_handler(repository, provider=provider)(job)

    assert repository.failed == [(job.resource_id, "DIAGNOSIS_PROVIDER_AUTH_FAILED")]
    assert repository.released == []


async def test_diagnosis_handler_releases_transient_failure_for_retry() -> None:
    repository = FakeRepository()
    provider = FakeProvider(DiagnosisTransientError("temporary"))
    job = make_job()

    with pytest.raises(DiagnosisTransientError):
        await build_handler(repository, provider=provider)(job)

    assert repository.released == [job.resource_id]
    assert repository.failed == []


async def test_diagnosis_handler_marks_missing_media_as_permanent() -> None:
    repository = FakeRepository()
    storage = FakeStorage(
        AppError(
            code="MEDIA_UPLOAD_NOT_FOUND",
            message="업로드된 파일을 찾을 수 없습니다.",
            status_code=409,
        )
    )
    job = make_job()

    with pytest.raises(PermanentTaskError):
        await build_handler(repository, storage=storage)(job)

    assert repository.failed == [(job.resource_id, "MEDIA_UPLOAD_NOT_FOUND")]
    assert repository.released == []


async def test_diagnosis_handler_ignores_already_processed_job() -> None:
    repository = FakeRepository()
    repository.work = None
    provider = FakeProvider()

    await build_handler(repository, provider=provider)(make_job())

    assert provider.calls == 0
    assert repository.completed == []


async def test_diagnosis_handler_marks_retry_exhaustion() -> None:
    repository = FakeRepository()
    job = make_job()

    await build_handler(repository).on_exhausted(job)

    assert repository.failed == [(job.resource_id, "DIAGNOSIS_PROVIDER_UNAVAILABLE")]
