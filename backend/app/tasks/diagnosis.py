import asyncio
import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import func, select, update

from app.core.errors import AppError
from app.db.session import Database
from app.integrations.diagnosis import (
    DiagnosisImageQualityChecker,
    DiagnosisImageQualityResult,
    DiagnosisPermanentError,
    DiagnosisProvider,
    DiagnosisProviderResult,
    DiagnosisRetakeError,
    DiagnosisTransientError,
)
from app.integrations.storage import StorageGateway
from app.models.chat import AIConversation, AIMessage
from app.models.diagnosis import Diagnosis
from app.models.enums import AIMessageStatus, ChatRole, DiagnosisCondition, DiagnosisStatus
from app.models.media import MediaFile
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


class SQLAlchemyDiagnosisRepository:
    def __init__(self, database: Database) -> None:
        self._database = database

    async def start(self, diagnosis_id: UUID) -> DiagnosisWork | None:
        async with self._database.session_context() as session:
            row = (
                await session.execute(
                    update(Diagnosis)
                    .where(
                        Diagnosis.id == diagnosis_id,
                        Diagnosis.status == DiagnosisStatus.PENDING,
                    )
                    .values(
                        status=DiagnosisStatus.PROCESSING.value,
                        started_at=datetime.now(UTC),
                        completed_at=None,
                        failure_code=None,
                    )
                    .returning(
                        Diagnosis.media_file_id,
                        Diagnosis.input_context_snapshot,
                    )
                )
            ).one_or_none()
            if row is None:
                return None
            media = await session.get(MediaFile, row.media_file_id)
            if media is None:
                await session.execute(
                    update(Diagnosis)
                    .where(Diagnosis.id == diagnosis_id)
                    .values(
                        status=DiagnosisStatus.FAILED.value,
                        failure_code="MEDIA_UPLOAD_NOT_FOUND",
                        completed_at=datetime.now(UTC),
                    )
                )
                return None
            return DiagnosisWork(
                object_path=media.object_path,
                content_type=media.content_type,
                input_context=row.input_context_snapshot or {},
            )

    async def complete(
        self,
        diagnosis_id: UUID,
        quality: DiagnosisImageQualityResult,
        result: DiagnosisProviderResult,
        recommended_care: list[str],
    ) -> None:
        async with self._database.session_context() as session:
            diagnosis = await session.scalar(
                select(Diagnosis).where(Diagnosis.id == diagnosis_id).with_for_update()
            )
            if diagnosis is None or diagnosis.status != DiagnosisStatus.PROCESSING:
                return
            diagnosis.status = DiagnosisStatus.COMPLETED.value
            diagnosis.overall_condition = result.overall_condition.value
            diagnosis.image_quality_result = quality.model_dump(mode="json")
            diagnosis.condition_label = result.condition_label
            diagnosis.observations = result.observations
            diagnosis.possible_causes = [
                cause.model_dump(mode="json", exclude_none=True) for cause in result.possible_causes
            ]
            diagnosis.recommended_care = recommended_care
            diagnosis.retake_reason_code = None
            diagnosis.failure_code = None
            diagnosis.diagnosis_provider = result.provider_name
            diagnosis.diagnosis_model_name = result.model_name
            diagnosis.provider_response_id = result.response_id
            diagnosis.care_rule_version = "kindwise-treatment-v1"
            diagnosis.latency_ms = result.latency_ms
            diagnosis.estimated_cost = result.estimated_cost
            diagnosis.cost_currency = result.cost_currency
            diagnosis.completed_at = datetime.now(UTC)

            if diagnosis.related_conversation_id is not None:
                session.add(
                    AIMessage(
                        id=uuid4(),
                        conversation_id=diagnosis.related_conversation_id,
                        related_diagnosis_id=diagnosis.id,
                        media_file_id=diagnosis.media_file_id,
                        role=ChatRole.ASSISTANT.value,
                        status=AIMessageStatus.COMPLETED.value,
                        content="진단 결과가 생성되었습니다. 진단표에서 확인해 주세요.",
                        provider=result.provider_name,
                        model_name=result.model_name,
                        provider_response_id=result.response_id,
                        created_at=datetime.now(UTC),
                    )
                )
                conversation = await session.get(
                    AIConversation,
                    diagnosis.related_conversation_id,
                )
                if conversation is not None:
                    conversation.last_message_at = datetime.now(UTC)

    async def needs_retake(
        self,
        diagnosis_id: UUID,
        quality: DiagnosisImageQualityResult,
    ) -> None:
        async with self._database.session_context() as session:
            await session.execute(
                update(Diagnosis)
                .where(
                    Diagnosis.id == diagnosis_id,
                    Diagnosis.status == DiagnosisStatus.PROCESSING,
                )
                .values(
                    status=DiagnosisStatus.NEEDS_RETAKE.value,
                    image_quality_result=quality.model_dump(mode="json"),
                    retake_reason_code=quality.retake_reason_code,
                    failure_code=None,
                    completed_at=datetime.now(UTC),
                )
            )

    async def release_for_retry(self, diagnosis_id: UUID, failure_code: str) -> None:
        async with self._database.session_context() as session:
            await session.execute(
                update(Diagnosis)
                .where(
                    Diagnosis.id == diagnosis_id,
                    Diagnosis.status == DiagnosisStatus.PROCESSING,
                )
                .values(
                    status=DiagnosisStatus.PENDING.value,
                    failure_code=failure_code,
                )
            )

    async def fail(self, diagnosis_id: UUID, failure_code: str) -> None:
        async with self._database.session_context() as session:
            await session.execute(
                update(Diagnosis)
                .where(
                    Diagnosis.id == diagnosis_id,
                    Diagnosis.status.in_(
                        [DiagnosisStatus.PENDING.value, DiagnosisStatus.PROCESSING.value]
                    ),
                )
                .values(
                    status=DiagnosisStatus.FAILED.value,
                    failure_code=failure_code,
                    completed_at=datetime.now(UTC),
                )
            )

    async def fail_after_retries(
        self,
        diagnosis_id: UUID,
        fallback_failure_code: str,
    ) -> None:
        async with self._database.session_context() as session:
            await session.execute(
                update(Diagnosis)
                .where(
                    Diagnosis.id == diagnosis_id,
                    Diagnosis.status.in_(
                        [DiagnosisStatus.PENDING.value, DiagnosisStatus.PROCESSING.value]
                    ),
                )
                .values(
                    status=DiagnosisStatus.FAILED.value,
                    failure_code=func.coalesce(
                        Diagnosis.failure_code,
                        fallback_failure_code,
                    ),
                    completed_at=datetime.now(UTC),
                )
            )


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
        except DiagnosisRetakeError as exc:
            await self._repository.needs_retake(
                job.resource_id,
                DiagnosisImageQualityResult(
                    acceptable=False,
                    plant_visible=False,
                    sharp_enough=True,
                    brightness_acceptable=True,
                    symptom_area_visible=False,
                    retake_reason_code=exc.reason_code,
                ),
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


def build_recommended_care(result: DiagnosisProviderResult, context: dict) -> list[str]:
    del context
    if result.care_suggestions:
        return result.care_suggestions
    if result.overall_condition == DiagnosisCondition.HEALTHY:
        return ["현재 관리 방법을 유지하고 정기적으로 상태를 확인해 주세요."]
    return ["3일 후 같은 부위를 다시 촬영해 상태 변화를 확인해 주세요."]
