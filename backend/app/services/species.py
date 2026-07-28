import base64
import json
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.enums import MediaPurpose, MediaStatus, SpeciesIdentificationStatus
from app.models.media import MediaFile, SpeciesIdentification
from app.models.plant import SpeciesCareGuide
from app.schemas.species import (
    RecommendedWater,
    SpeciesCandidate,
    SpeciesIdentificationCreatedResponse,
    SpeciesIdentificationResponse,
    SpeciesSearchResponse,
)


class SpeciesRepository(Protocol):
    async def search_guides(
        self,
        query: str,
        *,
        offset: int,
        limit: int,
    ) -> list[SpeciesCareGuide]: ...

    async def get_media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None: ...

    async def add_identification(self, identification: SpeciesIdentification) -> None: ...

    async def get_identification_owned(
        self,
        identification_id: UUID,
        user_id: UUID,
    ) -> SpeciesIdentification | None: ...


class SQLAlchemySpeciesRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def search_guides(
        self,
        query: str,
        *,
        offset: int,
        limit: int,
    ) -> list[SpeciesCareGuide]:
        escaped = query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        pattern = f"%{escaped}%"
        statement = (
            select(SpeciesCareGuide)
            .where(
                SpeciesCareGuide.active.is_(True),
                or_(
                    SpeciesCareGuide.display_name.ilike(pattern, escape="\\"),
                    SpeciesCareGuide.scientific_name.ilike(pattern, escape="\\"),
                ),
            )
            .order_by(SpeciesCareGuide.display_name, SpeciesCareGuide.species_reference_id)
            .offset(offset)
            .limit(limit)
        )
        return list((await self._session.scalars(statement)).all())

    async def get_media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None:
        return await self._session.scalar(
            select(MediaFile).where(
                MediaFile.id == media_file_id,
                MediaFile.user_id == user_id,
                MediaFile.deleted_at.is_(None),
            )
        )

    async def add_identification(self, identification: SpeciesIdentification) -> None:
        self._session.add(identification)
        await self._session.flush()

    async def get_identification_owned(
        self,
        identification_id: UUID,
        user_id: UUID,
    ) -> SpeciesIdentification | None:
        return await self._session.scalar(
            select(SpeciesIdentification).where(
                SpeciesIdentification.id == identification_id,
                SpeciesIdentification.user_id == user_id,
            )
        )


class SpeciesService:
    def __init__(self, repository: SpeciesRepository) -> None:
        self._repository = repository

    async def search(self, query: str, cursor: str | None, limit: int) -> SpeciesSearchResponse:
        normalized_query = query.strip()
        if len(normalized_query) < 2:
            raise AppError(
                code="SPECIES_QUERY_TOO_SHORT",
                message="검색어를 두 글자 이상 입력해 주세요.",
                status_code=422,
            )
        offset = decode_cursor(cursor)
        guides = await self._repository.search_guides(
            normalized_query,
            offset=offset,
            limit=limit + 1,
        )
        has_next = len(guides) > limit
        items = [guide_to_candidate(guide) for guide in guides[:limit]]
        return SpeciesSearchResponse(
            items=items,
            has_next=has_next,
            next_cursor=encode_cursor(offset + limit) if has_next else None,
        )

    async def create_identification(
        self,
        user_id: UUID,
        media_file_id: UUID,
    ) -> SpeciesIdentificationCreatedResponse:
        media_file = await self._repository.get_media_owned(media_file_id, user_id)
        if media_file is None:
            raise AppError(
                code="MEDIA_FILE_NOT_FOUND",
                message="파일을 찾을 수 없습니다.",
                status_code=404,
            )
        if media_file.purpose != MediaPurpose.SPECIES_IDENTIFICATION:
            raise AppError(
                code="MEDIA_PURPOSE_MISMATCH",
                message="식물 인식용으로 업로드한 사진이 아닙니다.",
                status_code=409,
            )
        if media_file.status != MediaStatus.READY:
            raise AppError(
                code="MEDIA_NOT_READY",
                message="아직 사용할 수 없는 파일입니다.",
                status_code=409,
            )
        if media_file.content_type not in {"image/jpeg", "image/png"}:
            raise AppError(
                code="SPECIES_IMAGE_TYPE_UNSUPPORTED",
                message="식물 사진 인식은 JPEG 또는 PNG 형식만 지원합니다.",
                status_code=422,
            )

        created_at = datetime.now(UTC)
        identification = SpeciesIdentification(
            id=uuid4(),
            user_id=user_id,
            media_file_id=media_file_id,
            status=SpeciesIdentificationStatus.PENDING.value,
            created_at=created_at,
        )
        await self._repository.add_identification(identification)
        return SpeciesIdentificationCreatedResponse(
            id=identification.id,
            status=SpeciesIdentificationStatus.PENDING,
            created_at=created_at,
        )

    async def get_identification(
        self,
        user_id: UUID,
        identification_id: UUID,
    ) -> SpeciesIdentificationResponse:
        identification = await self._repository.get_identification_owned(
            identification_id,
            user_id,
        )
        if identification is None:
            raise AppError(
                code="SPECIES_IDENTIFICATION_NOT_FOUND",
                message="식물 인식 결과를 찾을 수 없습니다.",
                status_code=404,
            )
        return SpeciesIdentificationResponse(
            id=identification.id,
            status=identification.status,
            candidates=identification.candidates or [],
            failure_code=identification.failure_code,
            completed_at=identification.completed_at,
        )


def guide_to_candidate(guide: SpeciesCareGuide) -> SpeciesCandidate:
    recommended_water = None
    if guide.recommended_water_min_ml is not None and guide.recommended_water_max_ml is not None:
        recommended_water = RecommendedWater(
            min_ml=guide.recommended_water_min_ml,
            max_ml=guide.recommended_water_max_ml,
            source=guide.water_recommendation_source,
        )
    return SpeciesCandidate(
        reference_id=guide.species_reference_id,
        display_name=guide.display_name,
        scientific_name=guide.scientific_name,
        category_suggestion=guide.category,
        recommended_water=recommended_water,
    )


def encode_cursor(offset: int) -> str:
    payload = json.dumps({"offset": offset}, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(payload).decode().rstrip("=")


def decode_cursor(cursor: str | None) -> int:
    if cursor is None:
        return 0
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded))
        offset = payload["offset"]
        if not isinstance(offset, int) or offset < 0:
            raise ValueError
        return offset
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise AppError(
            code="INVALID_CURSOR",
            message="유효하지 않은 커서입니다.",
            status_code=400,
        ) from exc
