import asyncio
from uuid import uuid4

import pytest

from app.core.errors import AppError
from app.integrations.diagnosis import (
    DiagnosisImageQualityResult,
    DiagnosisPermanentError,
    DiagnosisProviderResult,
    DiagnosisRetakeError,
    DiagnosisTransientError,
)
from app.schemas.queue import JobType, QueueJob
from app.tasks.base import PermanentTaskError
from app.tasks.diagnosis import DiagnosisHandler, DiagnosisWork, diagnosis_notification_copy


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
        self.last_retry_failure_code: str | None = None

    async def start(self, _diagnosis_id):
        return self.work

    async def complete(self, diagnosis_id, quality, result, recommended_care):
        self.completed.append((diagnosis_id, quality, result, recommended_care))

    async def needs_retake(self, diagnosis_id, quality):
        self.retake.append((diagnosis_id, quality))

    async def release_for_retry(self, diagnosis_id, failure_code):
        self.released.append(diagnosis_id)
        self.last_retry_failure_code = failure_code

    async def fail(self, diagnosis_id, failure_code):
        self.failed.append((diagnosis_id, failure_code))

    async def fail_after_retries(self, diagnosis_id, fallback_failure_code):
        self.failed.append((diagnosis_id, self.last_retry_failure_code or fallback_failure_code))


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


def test_diagnosis_notification_uses_plant_personality_copy() -> None:
    assert diagnosis_notification_copy("새싹이", "CHIC") == (
        "식물 진단이 완료됐어요",
        "새싹이 진단 결과 나왔어. 확인해.",
    )
    assert diagnosis_notification_copy("새싹이", "UNKNOWN")[1] == (
        "새싹이의 진단 결과를 확인해 주세요."
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


async def test_diagnosis_handler_marks_nonplant_provider_result_for_retake() -> None:
    repository = FakeRepository()
    provider = FakeProvider(DiagnosisRetakeError("PLANT_NOT_VISIBLE"))
    job = make_job()

    await build_handler(repository, provider=provider)(job)

    assert repository.retake[0][0] == job.resource_id
    assert repository.retake[0][1].plant_visible is False
    assert repository.retake[0][1].retake_reason_code == "PLANT_NOT_VISIBLE"
    assert repository.released == []
    assert repository.failed == []


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

    assert repository.failed == [(job.resource_id, "DIAGNOSIS_RETRY_EXHAUSTED")]


async def test_diagnosis_handler_preserves_failure_code_on_retry_exhaustion() -> None:
    repository = FakeRepository()
    job = make_job()
    error = AppError(
        code="STORAGE_TEMPORARILY_UNAVAILABLE",
        message="스토리지를 일시적으로 사용할 수 없습니다.",
        status_code=503,
    )

    with pytest.raises(AppError):
        await build_handler(repository, storage=FakeStorage(error))(job)
    await build_handler(repository).on_exhausted(job)

    assert repository.failed == [(job.resource_id, "STORAGE_TEMPORARILY_UNAVAILABLE")]


async def test_diagnosis_handler_times_out_external_call() -> None:
    class SlowStorage(FakeStorage):
        async def download_object(self, object_path: str) -> bytes:
            await asyncio.sleep(1)
            return await super().download_object(object_path)

    repository = FakeRepository()
    job = make_job()
    handler = DiagnosisHandler(
        repository,
        SlowStorage(),
        FakeQualityChecker(accepted_quality()),
        FakeProvider(),
        lambda _result, _context: ["물을 주세요."],
        external_call_timeout_seconds=0.001,
    )

    with pytest.raises(TimeoutError):
        await handler(job)

    assert repository.released == [job.resource_id]
    assert repository.last_retry_failure_code == "DIAGNOSIS_EXTERNAL_TIMEOUT"


async def test_diagnosis_handler_marks_empty_recommended_care_as_permanent() -> None:
    repository = FakeRepository()
    job = make_job()
    handler = DiagnosisHandler(
        repository,
        FakeStorage(),
        FakeQualityChecker(accepted_quality()),
        FakeProvider(),
        lambda _result, _context: ["   "],
    )

    with pytest.raises(PermanentTaskError):
        await handler(job)

    assert repository.failed == [(job.resource_id, "DIAGNOSIS_CARE_RULE_EMPTY")]
    assert repository.released == []
