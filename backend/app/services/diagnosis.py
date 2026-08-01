import base64
import binascii
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.integrations.storage import StorageGateway
from app.models.care import CareEvent
from app.models.chat import AIConversation
from app.models.diagnosis import Diagnosis
from app.models.enums import (
    CareEventStatus,
    CareEventType,
    DiagnosisStatus,
    MediaPurpose,
    MediaStatus,
)
from app.models.media import MediaFile
from app.models.plant import Plant, SpeciesCareGuide
from app.schemas.diagnosis import (
    DiagnosisCreatedResponse,
    DiagnosisCreateRequest,
    DiagnosisDetailResponse,
    DiagnosisListItem,
    DiagnosisListResponse,
    DiagnosisStatusResponse,
)

RETRYABLE_FAILURE_CODES = {
    "DATABASE_UNAVAILABLE",
    "DIAGNOSIS_EXTERNAL_TIMEOUT",
    "DIAGNOSIS_PROVIDER_UNAVAILABLE",
    "DIAGNOSIS_RETRY_EXHAUSTED",
    "DIAGNOSIS_UNEXPECTED_ERROR",
    "KINDWISE_INVALID_RESPONSE",
    "STORAGE_UNAVAILABLE",
}


@dataclass(frozen=True, slots=True)
class PlantDiagnosisContext:
    plant: Plant
    guide: SpeciesCareGuide
    last_watered_on: str | None
    last_repotted_on: str | None


@dataclass(frozen=True, slots=True)
class DiagnosisRecord:
    diagnosis: Diagnosis
    object_path: str


class DiagnosisAPIRepository(Protocol):
    async def plant_context_owned(
        self, plant_id: UUID, user_id: UUID
    ) -> PlantDiagnosisContext | None: ...

    async def conversation_owned(
        self, conversation_id: UUID, user_id: UUID
    ) -> AIConversation | None: ...

    async def media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None: ...

    async def diagnosis_by_media_owned(
        self, media_file_id: UUID, user_id: UUID
    ) -> Diagnosis | None: ...

    async def add(self, diagnosis: Diagnosis) -> Diagnosis: ...

    async def list_owned(
        self, plant_id: UUID, user_id: UUID, offset: int, limit: int
    ) -> list[DiagnosisRecord]: ...

    async def get_owned(
        self, diagnosis_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> DiagnosisRecord | None: ...


class SQLAlchemyDiagnosisAPIRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def plant_context_owned(
        self, plant_id: UUID, user_id: UUID
    ) -> PlantDiagnosisContext | None:
        row = (
            await self._session.execute(
                select(Plant, SpeciesCareGuide)
                .join(
                    SpeciesCareGuide,
                    SpeciesCareGuide.species_reference_id == Plant.species_reference_id,
                )
                .where(
                    Plant.id == plant_id,
                    Plant.user_id == user_id,
                    Plant.deleted_at.is_(None),
                )
            )
        ).one_or_none()
        if row is None:
            return None
        plant, guide = row
        events = (
            await self._session.execute(
                select(CareEvent.type, CareEvent.performed_on)
                .where(
                    CareEvent.plant_id == plant_id,
                    CareEvent.status == CareEventStatus.COMPLETED,
                    CareEvent.type.in_([CareEventType.WATERING, CareEventType.REPOTTING]),
                )
                .order_by(CareEvent.performed_on.desc())
            )
        ).all()
        latest: dict[str, str] = {}
        for event_type, performed_on in events:
            if event_type not in latest and performed_on is not None:
                latest[event_type] = performed_on.isoformat()
        return PlantDiagnosisContext(
            plant=plant,
            guide=guide,
            last_watered_on=latest.get(CareEventType.WATERING),
            last_repotted_on=latest.get(CareEventType.REPOTTING),
        )

    async def conversation_owned(
        self, conversation_id: UUID, user_id: UUID
    ) -> AIConversation | None:
        return await self._session.scalar(
            select(AIConversation)
            .join(Plant, Plant.id == AIConversation.plant_id)
            .where(
                AIConversation.id == conversation_id,
                AIConversation.deleted_at.is_(None),
                Plant.user_id == user_id,
                Plant.deleted_at.is_(None),
            )
        )

    async def media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None:
        return await self._session.scalar(
            select(MediaFile).where(
                MediaFile.id == media_file_id,
                MediaFile.user_id == user_id,
                MediaFile.deleted_at.is_(None),
            )
        )

    async def diagnosis_by_media_owned(
        self, media_file_id: UUID, user_id: UUID
    ) -> Diagnosis | None:
        return await self._session.scalar(
            select(Diagnosis)
            .join(Plant, Plant.id == Diagnosis.plant_id)
            .where(Diagnosis.media_file_id == media_file_id, Plant.user_id == user_id)
        )

    async def add(self, diagnosis: Diagnosis) -> Diagnosis:
        try:
            async with self._session.begin_nested():
                self._session.add(diagnosis)
                await self._session.flush()
            return diagnosis
        except IntegrityError:
            existing = await self._session.scalar(
                select(Diagnosis).where(Diagnosis.media_file_id == diagnosis.media_file_id)
            )
            if existing is None:
                raise
            return existing

    async def list_owned(
        self, plant_id: UUID, user_id: UUID, offset: int, limit: int
    ) -> list[DiagnosisRecord]:
        rows = (
            await self._session.execute(
                select(Diagnosis, MediaFile.object_path)
                .join(Plant, Plant.id == Diagnosis.plant_id)
                .join(MediaFile, MediaFile.id == Diagnosis.media_file_id)
                .where(
                    Diagnosis.plant_id == plant_id,
                    Plant.user_id == user_id,
                    Plant.deleted_at.is_(None),
                )
                .order_by(Diagnosis.created_at.desc(), Diagnosis.id.desc())
                .offset(offset)
                .limit(limit)
            )
        ).all()
        return [DiagnosisRecord(diagnosis=row[0], object_path=row[1]) for row in rows]

    async def get_owned(
        self, diagnosis_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> DiagnosisRecord | None:
        statement = (
            select(Diagnosis, MediaFile.object_path)
            .join(Plant, Plant.id == Diagnosis.plant_id)
            .join(MediaFile, MediaFile.id == Diagnosis.media_file_id)
            .where(
                Diagnosis.id == diagnosis_id,
                Plant.user_id == user_id,
                Plant.deleted_at.is_(None),
            )
        )
        if lock:
            statement = statement.with_for_update(of=Diagnosis)
        row = (await self._session.execute(statement)).one_or_none()
        return DiagnosisRecord(row[0], row[1]) if row is not None else None


class DiagnosisService:
    def __init__(
        self,
        repository: DiagnosisAPIRepository,
        storage: StorageGateway,
        *,
        provider_configured: bool,
        download_url_expires_seconds: int,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._provider_configured = provider_configured
        self._download_url_expires_seconds = download_url_expires_seconds

    async def create(
        self,
        user_id: UUID,
        plant_id: UUID,
        request: DiagnosisCreateRequest,
    ) -> tuple[DiagnosisCreatedResponse, bool]:
        if not self._provider_configured:
            raise AppError(
                code="DIAGNOSIS_PROVIDER_NOT_CONFIGURED",
                message="식물 진단 설정이 완료되지 않았습니다.",
                status_code=503,
            )
        context = await self._repository.plant_context_owned(plant_id, user_id)
        if context is None:
            raise AppError(
                code="PLANT_NOT_FOUND", message="식물을 찾을 수 없습니다.", status_code=404
            )
        conversation = await self._repository.conversation_owned(request.conversation_id, user_id)
        if conversation is None or conversation.plant_id != plant_id:
            raise AppError(
                code="CONVERSATION_NOT_FOUND",
                message="해당 식물의 대화를 찾을 수 없습니다.",
                status_code=404,
            )
        media = await self._repository.media_owned(request.media_file_id, user_id)
        if media is None:
            raise AppError(
                code="MEDIA_FILE_NOT_FOUND", message="파일을 찾을 수 없습니다.", status_code=404
            )
        if media.purpose != MediaPurpose.DIAGNOSIS:
            raise AppError(
                code="MEDIA_PURPOSE_MISMATCH",
                message="진단용으로 업로드한 사진이 아닙니다.",
                status_code=409,
            )
        if media.status != MediaStatus.READY:
            raise AppError(
                code="MEDIA_NOT_READY", message="아직 사용할 수 없는 파일입니다.", status_code=409
            )
        if media.content_type not in {"image/jpeg", "image/png", "image/webp"}:
            raise AppError(
                code="DIAGNOSIS_IMAGE_TYPE_UNSUPPORTED",
                message="지원하지 않는 사진 형식입니다.",
                status_code=422,
            )

        existing = await self._repository.diagnosis_by_media_owned(request.media_file_id, user_id)
        if existing is not None:
            return _created_response(existing), False

        diagnosis = Diagnosis(
            id=uuid4(),
            plant_id=plant_id,
            related_conversation_id=conversation.id,
            media_file_id=media.id,
            status=DiagnosisStatus.PENDING.value,
            input_context_snapshot={
                "nickname": context.plant.nickname,
                "species_name": context.guide.display_name,
                "scientific_name": context.guide.scientific_name,
                "place_name": context.plant.place_name,
                "pot_type": context.plant.pot_type,
                "placement": context.plant.placement,
                "last_watered_on": context.last_watered_on,
                "last_repotted_on": context.last_repotted_on,
                "diagnosis_profile": context.guide.diagnosis_profile or {},
            },
            created_at=datetime.now(UTC),
        )
        persisted = await self._repository.add(diagnosis)
        return _created_response(persisted), persisted.id == diagnosis.id

    async def list(
        self, user_id: UUID, plant_id: UUID, cursor: str | None, limit: int
    ) -> DiagnosisListResponse:
        if await self._repository.plant_context_owned(plant_id, user_id) is None:
            raise AppError(
                code="PLANT_NOT_FOUND", message="식물을 찾을 수 없습니다.", status_code=404
            )
        offset = _decode_cursor(cursor)
        records = await self._repository.list_owned(plant_id, user_id, offset, limit + 1)
        has_next = len(records) > limit
        items = [await self._list_item(record) for record in records[:limit]]
        return DiagnosisListResponse(
            items=items,
            has_next=has_next,
            next_cursor=_encode_cursor(offset + limit) if has_next else None,
        )

    async def get(self, user_id: UUID, diagnosis_id: UUID) -> DiagnosisDetailResponse:
        record = await self._require_owned(user_id, diagnosis_id)
        photo_url = await self._photo_url(record.object_path)
        item = record.diagnosis
        return DiagnosisDetailResponse(
            id=item.id,
            plant_id=item.plant_id,
            status=item.status,
            diagnosed_at=item.completed_at or item.created_at,
            photo_url=photo_url,
            overall_condition=item.overall_condition,
            condition_label=item.condition_label,
            observations=item.observations or [],
            possible_causes=item.possible_causes or [],
            recommended_care=item.recommended_care or [],
            retake_reason_code=item.retake_reason_code,
            failure_code=item.failure_code,
            related_conversation_id=item.related_conversation_id,
        )

    async def retry(self, user_id: UUID, diagnosis_id: UUID) -> DiagnosisStatusResponse:
        record = await self._require_owned(user_id, diagnosis_id, lock=True)
        item = record.diagnosis
        if (
            item.status != DiagnosisStatus.FAILED
            or item.failure_code not in RETRYABLE_FAILURE_CODES
        ):
            raise AppError(
                code="DIAGNOSIS_NOT_RETRYABLE",
                message="다시 시도할 수 없는 진단입니다.",
                status_code=409,
            )
        item.status = DiagnosisStatus.PENDING.value
        item.failure_code = None
        item.started_at = None
        item.completed_at = None
        return DiagnosisStatusResponse(diagnosis_id=item.id, status=item.status)

    async def cancel(self, user_id: UUID, diagnosis_id: UUID) -> None:
        record = await self._require_owned(user_id, diagnosis_id, lock=True)
        item = record.diagnosis
        if item.status != DiagnosisStatus.PENDING:
            raise AppError(
                code="DIAGNOSIS_NOT_CANCELLABLE",
                message="대기 중인 진단만 취소할 수 있습니다.",
                status_code=409,
            )
        item.status = DiagnosisStatus.CANCELLED.value
        item.completed_at = datetime.now(UTC)

    async def _list_item(self, record: DiagnosisRecord) -> DiagnosisListItem:
        item = record.diagnosis
        return DiagnosisListItem(
            id=item.id,
            status=item.status,
            diagnosed_at=item.completed_at or item.created_at,
            photo_url=await self._photo_url(record.object_path),
            condition_label=item.condition_label,
            retake_reason_code=item.retake_reason_code,
            failure_code=item.failure_code,
        )

    async def _require_owned(
        self, user_id: UUID, diagnosis_id: UUID, *, lock: bool = False
    ) -> DiagnosisRecord:
        record = await self._repository.get_owned(diagnosis_id, user_id, lock=lock)
        if record is None:
            raise AppError(
                code="DIAGNOSIS_NOT_FOUND",
                message="진단 결과를 찾을 수 없습니다.",
                status_code=404,
            )
        return record

    async def _photo_url(self, object_path: str) -> str:
        return await self._storage.create_signed_download_url(
            object_path,
            expires_in=self._download_url_expires_seconds,
        )


def _created_response(diagnosis: Diagnosis) -> DiagnosisCreatedResponse:
    return DiagnosisCreatedResponse(
        diagnosis_id=diagnosis.id,
        status=diagnosis.status,
        created_at=diagnosis.created_at,
    )


def _encode_cursor(offset: int) -> str:
    return base64.urlsafe_b64encode(str(offset).encode()).decode().rstrip("=")


def _decode_cursor(cursor: str | None) -> int:
    if cursor is None:
        return 0
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        offset = int(base64.urlsafe_b64decode(padded).decode())
    except (binascii.Error, ValueError, UnicodeDecodeError) as exc:
        raise AppError(
            code="INVALID_CURSOR", message="페이지 정보를 확인해 주세요.", status_code=422
        ) from exc
    if offset < 0:
        raise AppError(
            code="INVALID_CURSOR", message="페이지 정보를 확인해 주세요.", status_code=422
        )
    return offset
