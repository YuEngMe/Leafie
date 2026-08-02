from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from typing import Protocol
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.integrations.storage import StorageGateway
from app.models.enums import MediaPurpose, MediaStatus
from app.models.media import MediaFile
from app.models.plant import Plant, PlantDiary
from app.models.user import UserProfile
from app.schemas.diary import (
    DiaryMediaResponse,
    DiaryMonthEntry,
    DiaryMonthResponse,
    DiaryMonthStatistics,
    DiaryResponse,
    DiaryUpsertRequest,
)

CONDITION_LEVELS = {0: 1, 25: 2, 50: 3, 75: 4, 100: 5}
AVERAGE_LEVEL_BOUNDARIES = (
    (Decimal("12.5"), 1),
    (Decimal("37.5"), 2),
    (Decimal("62.5"), 3),
    (Decimal("87.5"), 4),
)


@dataclass(frozen=True, slots=True)
class OwnedPlantContext:
    plant_id: UUID
    timezone: str


@dataclass(frozen=True, slots=True)
class DiaryMutationResult:
    response: DiaryResponse
    created: bool
    cleanup_media_ids: tuple[UUID, ...]


@dataclass(frozen=True, slots=True)
class DiaryDeletionResult:
    cleanup_media_ids: tuple[UUID, ...]


class DiaryRepository(Protocol):
    async def get_owned_plant_context(
        self,
        plant_id: UUID,
        user_id: UUID,
        *,
        lock: bool = False,
    ) -> OwnedPlantContext | None: ...

    async def get_diary(
        self,
        plant_id: UUID,
        diary_date: date,
        *,
        lock: bool = False,
    ) -> PlantDiary | None: ...

    async def list_diaries(
        self,
        plant_id: UUID,
        start_date: date,
        end_date: date,
    ) -> list[PlantDiary]: ...

    async def average_condition_score(
        self,
        plant_id: UUID,
        start_date: date,
        end_date: date,
    ) -> Decimal | None: ...

    async def get_media(
        self,
        media_file_id: UUID,
        user_id: UUID,
        *,
        lock: bool = False,
    ) -> MediaFile | None: ...

    async def media_is_used_by_other_diary(
        self,
        media_file_id: UUID,
        diary_id: UUID | None,
    ) -> bool: ...

    async def add_diary(self, diary: PlantDiary) -> None: ...

    async def delete_diary(self, diary: PlantDiary) -> None: ...

    async def flush(self) -> None: ...


class SQLAlchemyDiaryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_owned_plant_context(
        self,
        plant_id: UUID,
        user_id: UUID,
        *,
        lock: bool = False,
    ) -> OwnedPlantContext | None:
        statement = (
            select(Plant.id, UserProfile.timezone)
            .join(UserProfile, UserProfile.user_id == Plant.user_id)
            .where(
                Plant.id == plant_id,
                Plant.user_id == user_id,
                Plant.deleted_at.is_(None),
            )
        )
        if lock:
            statement = statement.with_for_update(of=Plant)
        row = (await self._session.execute(statement)).one_or_none()
        if row is None:
            return None
        return OwnedPlantContext(plant_id=row.id, timezone=row.timezone)

    async def get_diary(
        self,
        plant_id: UUID,
        diary_date: date,
        *,
        lock: bool = False,
    ) -> PlantDiary | None:
        statement = select(PlantDiary).where(
            PlantDiary.plant_id == plant_id,
            PlantDiary.diary_date == diary_date,
        )
        if lock:
            statement = statement.with_for_update()
        return await self._session.scalar(statement)

    async def list_diaries(
        self,
        plant_id: UUID,
        start_date: date,
        end_date: date,
    ) -> list[PlantDiary]:
        statement = (
            select(PlantDiary)
            .where(
                PlantDiary.plant_id == plant_id,
                PlantDiary.diary_date >= start_date,
                PlantDiary.diary_date < end_date,
            )
            .order_by(PlantDiary.diary_date)
        )
        return list((await self._session.scalars(statement)).all())

    async def average_condition_score(
        self,
        plant_id: UUID,
        start_date: date,
        end_date: date,
    ) -> Decimal | None:
        statement = select(func.avg(PlantDiary.condition_score)).where(
            PlantDiary.plant_id == plant_id,
            PlantDiary.diary_date >= start_date,
            PlantDiary.diary_date < end_date,
        )
        return await self._session.scalar(statement)

    async def get_media(
        self,
        media_file_id: UUID,
        user_id: UUID,
        *,
        lock: bool = False,
    ) -> MediaFile | None:
        statement = select(MediaFile).where(
            MediaFile.id == media_file_id,
            MediaFile.user_id == user_id,
        )
        if lock:
            statement = statement.with_for_update()
        return await self._session.scalar(statement)

    async def media_is_used_by_other_diary(
        self,
        media_file_id: UUID,
        diary_id: UUID | None,
    ) -> bool:
        statement = select(PlantDiary.id).where(PlantDiary.media_file_id == media_file_id)
        if diary_id is not None:
            statement = statement.where(PlantDiary.id != diary_id)
        return await self._session.scalar(statement.limit(1)) is not None

    async def add_diary(self, diary: PlantDiary) -> None:
        self._session.add(diary)
        await self._session.flush()

    async def delete_diary(self, diary: PlantDiary) -> None:
        await self._session.delete(diary)
        await self._session.flush()

    async def flush(self) -> None:
        await self._session.flush()


class DiaryService:
    def __init__(
        self,
        repository: DiaryRepository,
        storage: StorageGateway,
        *,
        download_url_expires_seconds: int = 300,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._download_url_expires_seconds = download_url_expires_seconds

    async def list_month(
        self,
        user_id: UUID,
        plant_id: UUID,
        year: int,
        month: int,
    ) -> DiaryMonthResponse:
        await self._require_owned_plant(user_id, plant_id)
        start_date, end_date = month_range(year, month)
        diaries = await self._repository.list_diaries(plant_id, start_date, end_date)
        average = await self._repository.average_condition_score(
            plant_id,
            start_date,
            end_date,
        )
        return DiaryMonthResponse(
            entries=[
                DiaryMonthEntry(
                    id=diary.id,
                    diary_date=diary.diary_date,
                    condition_score=diary.condition_score,
                    condition_level=condition_level(diary.condition_score),
                    has_photo=diary.media_file_id is not None,
                )
                for diary in diaries
            ],
            statistics=monthly_statistics(len(diaries), average),
        )

    async def get_diary(
        self,
        user_id: UUID,
        plant_id: UUID,
        diary_date: date,
    ) -> DiaryResponse:
        await self._require_owned_plant(user_id, plant_id)
        diary = await self._repository.get_diary(plant_id, diary_date)
        if diary is None:
            raise diary_not_found_error()
        return await self._build_response(user_id, diary)

    async def upsert_diary(
        self,
        user_id: UUID,
        plant_id: UUID,
        diary_date: date,
        request: DiaryUpsertRequest,
    ) -> DiaryMutationResult:
        context = await self._require_owned_plant(user_id, plant_id, lock=True)
        if diary_date > today_in_timezone(context.timezone):
            raise AppError(
                code="FUTURE_DATE_NOT_ALLOWED",
                message="미래 날짜의 다이어리는 작성할 수 없습니다.",
                status_code=400,
            )

        diary = await self._repository.get_diary(plant_id, diary_date, lock=True)
        media_was_provided = "media_file_id" in request.model_fields_set
        next_media_file_id = (
            request.media_file_id if media_was_provided or diary is None else diary.media_file_id
        )
        if media_was_provided and next_media_file_id is not None:
            await self._validate_new_media(
                user_id,
                next_media_file_id,
                diary.id if diary is not None else None,
            )

        now = datetime.now(UTC)
        created = diary is None
        previous_media_file_id = diary.media_file_id if diary is not None else None
        if diary is None:
            diary = PlantDiary(
                id=uuid4(),
                plant_id=plant_id,
                media_file_id=next_media_file_id,
                diary_date=diary_date,
                content=request.content,
                condition_score=request.condition_score,
                created_at=now,
                updated_at=now,
            )
            await self._repository.add_diary(diary)
        else:
            changed = (
                diary.content != request.content
                or diary.condition_score != request.condition_score
                or (media_was_provided and diary.media_file_id != next_media_file_id)
            )
            if changed:
                diary.content = request.content
                diary.condition_score = request.condition_score
                diary.media_file_id = next_media_file_id
                diary.updated_at = now
                await self._repository.flush()

        cleanup_media_ids: tuple[UUID, ...] = ()
        if previous_media_file_id is not None and previous_media_file_id != next_media_file_id:
            await self._mark_media_deleted(user_id, previous_media_file_id)
            cleanup_media_ids = (previous_media_file_id,)
            await self._repository.flush()

        return DiaryMutationResult(
            response=await self._build_response(user_id, diary),
            created=created,
            cleanup_media_ids=cleanup_media_ids,
        )

    async def delete_diary(
        self,
        user_id: UUID,
        plant_id: UUID,
        diary_date: date,
    ) -> DiaryDeletionResult:
        await self._require_owned_plant(user_id, plant_id, lock=True)
        diary = await self._repository.get_diary(plant_id, diary_date, lock=True)
        if diary is None:
            return DiaryDeletionResult(cleanup_media_ids=())

        media_file_id = diary.media_file_id
        await self._repository.delete_diary(diary)
        if media_file_id is not None:
            await self._mark_media_deleted(user_id, media_file_id)
            await self._repository.flush()
            return DiaryDeletionResult(cleanup_media_ids=(media_file_id,))
        return DiaryDeletionResult(cleanup_media_ids=())

    async def _require_owned_plant(
        self,
        user_id: UUID,
        plant_id: UUID,
        *,
        lock: bool = False,
    ) -> OwnedPlantContext:
        context = await self._repository.get_owned_plant_context(
            plant_id,
            user_id,
            lock=lock,
        )
        if context is None:
            raise AppError(
                code="PLANT_NOT_FOUND",
                message="식물을 찾을 수 없습니다.",
                status_code=404,
            )
        return context

    async def _validate_new_media(
        self,
        user_id: UUID,
        media_file_id: UUID,
        diary_id: UUID | None,
    ) -> None:
        media_file = await self._repository.get_media(media_file_id, user_id, lock=True)
        if media_file is None or media_file.deleted_at is not None:
            raise AppError(
                code="MEDIA_FILE_NOT_FOUND",
                message="파일을 찾을 수 없습니다.",
                status_code=404,
            )
        if media_file.purpose != MediaPurpose.DIARY:
            raise AppError(
                code="MEDIA_PURPOSE_MISMATCH",
                message="다이어리용으로 업로드한 사진이 아닙니다.",
                status_code=409,
            )
        if media_file.status != MediaStatus.READY:
            raise AppError(
                code="MEDIA_NOT_READY",
                message="아직 사용할 수 없는 파일입니다.",
                status_code=409,
            )
        if await self._repository.media_is_used_by_other_diary(media_file_id, diary_id):
            raise AppError(
                code="MEDIA_FILE_IN_USE",
                message="이미 다른 다이어리에 사용한 사진입니다.",
                status_code=409,
            )

    async def _mark_media_deleted(self, user_id: UUID, media_file_id: UUID) -> None:
        media_file = await self._repository.get_media(media_file_id, user_id, lock=True)
        if media_file is None:
            raise AppError(
                code="MEDIA_FILE_NOT_FOUND",
                message="파일을 찾을 수 없습니다.",
                status_code=404,
            )
        media_file.status = MediaStatus.DELETED.value
        media_file.deleted_at = datetime.now(UTC)

    async def _build_response(self, user_id: UUID, diary: PlantDiary) -> DiaryResponse:
        media_response: DiaryMediaResponse | None = None
        if diary.media_file_id is not None:
            media_file = await self._repository.get_media(diary.media_file_id, user_id)
            if media_file is not None and media_file.deleted_at is None:
                issued_at = datetime.now(UTC)
                download_url = await self._storage.create_signed_download_url(
                    media_file.object_path,
                    expires_in=self._download_url_expires_seconds,
                )
                media_response = DiaryMediaResponse(
                    id=media_file.id,
                    download_url=download_url,
                    expires_at=issued_at + timedelta(seconds=self._download_url_expires_seconds),
                )

        return DiaryResponse(
            id=diary.id,
            plant_id=diary.plant_id,
            diary_date=diary.diary_date,
            content=diary.content,
            condition_score=diary.condition_score,
            condition_level=condition_level(diary.condition_score),
            media=media_response,
            created_at=diary.created_at,
            updated_at=diary.updated_at,
        )


def condition_level(score: int) -> int:
    try:
        return CONDITION_LEVELS[score]
    except KeyError as exc:
        raise ValueError(f"Unsupported condition score: {score}") from exc


def monthly_statistics(entry_count: int, average: Decimal | None) -> DiaryMonthStatistics:
    if average is None:
        return DiaryMonthStatistics(
            entry_count=entry_count,
            average_score=None,
            average_level=None,
        )
    return DiaryMonthStatistics(
        entry_count=entry_count,
        average_score=int(average.quantize(Decimal("1"), rounding=ROUND_HALF_UP)),
        average_level=average_condition_level(average),
    )


def average_condition_level(average: Decimal) -> int:
    for upper_bound, level in AVERAGE_LEVEL_BOUNDARIES:
        if average < upper_bound:
            return level
    return 5


def month_range(year: int, month: int) -> tuple[date, date]:
    start_date = date(year, month, 1)
    if month == 12:
        return start_date, date(year + 1, 1, 1)
    return start_date, date(year, month + 1, 1)


def today_in_timezone(timezone_name: str) -> date:
    try:
        timezone = ZoneInfo(timezone_name)
    except (ZoneInfoNotFoundError, ValueError):
        timezone = ZoneInfo("Asia/Seoul")
    return datetime.now(timezone).date()


def diary_not_found_error() -> AppError:
    return AppError(
        code="DIARY_NOT_FOUND",
        message="다이어리를 찾을 수 없습니다.",
        status_code=404,
    )
