import asyncio
import logging
from collections.abc import Callable
from dataclasses import dataclass
from typing import Protocol
from uuid import UUID

from app.core.errors import AppError
from app.integrations.diagnosis import (
    DiagnosisImageQualityChecker,
    DiagnosisImageQualityResult,
    DiagnosisPermanentError,
    DiagnosisProvider,
    DiagnosisProviderResult,
    DiagnosisTransientError,
)
from app.integrations.storage import StorageGateway
from app.schemas.queue import QueueJob
from app.tasks.base import PermanentTaskError

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class DiagnosisWork:
    object_path: str
    content_type: str
    input_context: dict


class DiagnosisRepository(Protocol):
    async def start(self, diagnosis_id: UUID) -> DiagnosisWork | None: ...

    async def complete(
        self,
        diagnosis_id: UUID,
        quality: DiagnosisImageQualityResult,
        result: DiagnosisProviderResult,
        recommended_care: list[str],
    ) -> None: ...

    async def needs_retake(
        self,
        diagnosis_id: UUID,
        quality: DiagnosisImageQualityResult,
    ) -> None: ...

    async def release_for_retry(self, diagnosis_id: UUID, failure_code: str) -> None: ...

    async def fail(self, diagnosis_id: UUID, failure_code: str) -> None: ...

    async def fail_after_retries(
        self,
        diagnosis_id: UUID,
        fallback_failure_code: str,
    ) -> None: ...


class DiagnosisHandler:
    def __init__(
        self,
        repository: DiagnosisRepository,
        storage: StorageGateway,
        quality_checker: DiagnosisImageQualityChecker,
        provider: DiagnosisProvider,
        build_recommended_care: Callable[[DiagnosisProviderResult, dict], list[str]],
        *,
        external_call_timeout_seconds: float = 60.0,
    ) -> None:
        if external_call_timeout_seconds <= 0:
            raise ValueError("external_call_timeout_seconds는 0보다 커야 합니다.")
        self._repository = repository
        self._storage = storage
        self._quality_checker = quality_checker
        self._provider = provider
        self._build_recommended_care = build_recommended_care
        self._external_call_timeout_seconds = external_call_timeout_seconds

    async def __call__(self, job: QueueJob) -> None:
        work = await self._repository.start(job.resource_id)
        if work is None:
            return

        try:
            image = await asyncio.wait_for(
                self._storage.download_object(work.object_path),
                timeout=self._external_call_timeout_seconds,
            )
            quality = await asyncio.wait_for(
                self._quality_checker.check(image, work.content_type),
                timeout=self._external_call_timeout_seconds,
            )
            if not quality.acceptable:
                await self._repository.needs_retake(job.resource_id, quality)
                return

            result = await asyncio.wait_for(
                self._provider.diagnose(
                    image,
                    work.content_type,
                    work.input_context,
                ),
                timeout=self._external_call_timeout_seconds,
            )
            recommended_care = normalize_recommended_care(
                self._build_recommended_care(result, work.input_context)
            )
            await self._repository.complete(
                job.resource_id,
                quality,
                result,
                recommended_care,
            )
        except DiagnosisPermanentError as exc:
            await self._repository.fail(job.resource_id, exc.failure_code)
            raise PermanentTaskError(
                exc.failure_code,
                "식물 상태 진단을 완료할 수 없습니다.",
            ) from exc
        except AppError as exc:
            if exc.code == "MEDIA_UPLOAD_NOT_FOUND":
                await self._repository.fail(job.resource_id, exc.code)
                raise PermanentTaskError(exc.code, exc.message) from exc
            logger.warning(
                "Diagnosis AppError will retry resource_id=%s failure_code=%s",
                job.resource_id,
                exc.code,
            )
            await self._repository.release_for_retry(job.resource_id, exc.code)
            raise
        except DiagnosisTransientError:
            failure_code = "DIAGNOSIS_PROVIDER_UNAVAILABLE"
            logger.warning(
                "Diagnosis provider call will retry resource_id=%s failure_code=%s",
                job.resource_id,
                failure_code,
                exc_info=True,
            )
            await self._repository.release_for_retry(job.resource_id, failure_code)
            raise
        except TimeoutError:
            failure_code = "DIAGNOSIS_EXTERNAL_TIMEOUT"
            logger.warning(
                "Diagnosis external call timed out resource_id=%s failure_code=%s",
                job.resource_id,
                failure_code,
                exc_info=True,
            )
            await self._repository.release_for_retry(job.resource_id, failure_code)
            raise
        except Exception as exc:
            failure_code = "DIAGNOSIS_UNEXPECTED_ERROR"
            logger.exception(
                "Diagnosis unexpected error resource_id=%s failure_code=%s error_type=%s",
                job.resource_id,
                failure_code,
                type(exc).__name__,
            )
            await self._repository.release_for_retry(job.resource_id, failure_code)
            raise

    async def on_exhausted(self, job: QueueJob) -> None:
        await self._repository.fail_after_retries(
            job.resource_id,
            "DIAGNOSIS_RETRY_EXHAUSTED",
        )


def normalize_recommended_care(items: list[str]) -> list[str]:
    normalized = [item.strip() for item in items if item.strip()]
    if not normalized:
        raise DiagnosisPermanentError("DIAGNOSIS_CARE_RULE_EMPTY")
    return normalized[:10]
