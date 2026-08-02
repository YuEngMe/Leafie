from calendar import monthrange
from dataclasses import dataclass
from datetime import UTC, date, datetime
from typing import Protocol
from uuid import UUID

from sqlalchemy import and_, func, or_, select, union_all, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select

from app.core.errors import AppError
from app.integrations.storage import StorageGateway
from app.models.care import CareEvent
from app.models.chat import AIConversation, AIMessage
from app.models.diagnosis import Diagnosis
from app.models.enums import CareEventStatus, CareViewStatus, MediaStatus
from app.models.media import MediaFile, SpeciesIdentification
from app.models.notification import Notification
from app.models.plant import Plant, PlantDailyMemo, PlantDiary, SpeciesCareGuide
from app.models.user import UserProfile
from app.schemas.plant import (
    AgendaEventResponse,
    AgendaResponse,
    CalendarItemResponse,
    CalendarItemType,
    CalendarResponse,
    HomeCharacterResponse,
    HomeMemoResponse,
    HomePlantResponse,
    HomeResponse,
    PlantAppearanceUpdateRequest,
    PlantConditionResponse,
    PlantDetailResponse,
    PlantListItemResponse,
    PlantListResponse,
    PlantUpdateRequest,
)
from app.services.diary import condition_level
from app.services.plant import today_in_timezone


@dataclass(frozen=True, slots=True)
class PlantContext:
    plant: Plant
    guide: SpeciesCareGuide
    timezone: str


@dataclass(frozen=True, slots=True)
class DeletePlantResult:
    enqueue_cleanup: bool


def plant_media_ids_query(plant_id: UUID) -> Select:
    media_ids = union_all(
        select(Plant.primary_media_file_id.label("media_id")).where(Plant.id == plant_id),
        select(SpeciesIdentification.media_file_id.label("media_id"))
        .join(Plant, Plant.species_identification_id == SpeciesIdentification.id)
        .where(Plant.id == plant_id),
        select(PlantDiary.media_file_id.label("media_id")).where(PlantDiary.plant_id == plant_id),
        select(Diagnosis.media_file_id.label("media_id")).where(Diagnosis.plant_id == plant_id),
        select(AIMessage.media_file_id.label("media_id"))
        .join(AIConversation, AIConversation.id == AIMessage.conversation_id)
        .where(AIConversation.plant_id == plant_id),
    ).subquery()
    return select(media_ids.c.media_id).where(media_ids.c.media_id.is_not(None)).distinct()


class PlantManagementRepository(Protocol):
    async def get_profile(self, user_id: UUID, *, lock: bool = False) -> UserProfile | None: ...

    async def list_plants(self, user_id: UUID) -> list[PlantContext]: ...

    async def get_plant(
        self, user_id: UUID, plant_id: UUID, *, lock: bool = False
    ) -> PlantContext | None: ...

    async def get_plant_for_delete(self, user_id: UUID, plant_id: UUID) -> Plant | None: ...

    async def get_diary(self, plant_id: UUID, diary_date: date) -> PlantDiary | None: ...

    async def get_media(self, user_id: UUID, media_file_id: UUID) -> MediaFile | None: ...

    async def list_active_events(self, plant_id: UUID) -> list[CareEvent]: ...

    async def list_today_events(self, plant_id: UUID, today: date) -> list[CareEvent]: ...

    async def list_calendar_events(
        self, plant_id: UUID, date_from: date, date_to: date, types: set[str]
    ) -> list[CareEvent]: ...

    async def list_calendar_diaries(
        self, plant_id: UUID, date_from: date, date_to: date
    ) -> list[PlantDiary]: ...

    async def get_memo(self, plant_id: UUID, memo_date: date) -> PlantDailyMemo | None: ...

    async def count_unread_notifications(self, user_id: UUID) -> int: ...

    async def oldest_remaining_plant_id(
        self, user_id: UUID, excluded_plant_id: UUID
    ) -> UUID | None: ...

    async def mark_plant_media_deleted(self, plant_id: UUID, user_id: UUID) -> None: ...

    async def flush(self) -> None: ...


class SQLAlchemyPlantManagementRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_profile(self, user_id: UUID, *, lock: bool = False) -> UserProfile | None:
        statement = select(UserProfile).where(UserProfile.user_id == user_id)
        if lock:
            statement = statement.with_for_update()
        return await self._session.scalar(statement)

    async def list_plants(self, user_id: UUID) -> list[PlantContext]:
        rows = await self._session.execute(
            select(Plant, SpeciesCareGuide, UserProfile.timezone)
            .join(
                SpeciesCareGuide,
                SpeciesCareGuide.species_reference_id == Plant.species_reference_id,
            )
            .join(UserProfile, UserProfile.user_id == Plant.user_id)
            .where(Plant.user_id == user_id, Plant.deleted_at.is_(None))
            .order_by(Plant.created_at, Plant.id)
        )
        return [PlantContext(plant=row[0], guide=row[1], timezone=row.timezone) for row in rows]

    async def get_plant(
        self, user_id: UUID, plant_id: UUID, *, lock: bool = False
    ) -> PlantContext | None:
        statement = (
            select(Plant, SpeciesCareGuide, UserProfile.timezone)
            .join(
                SpeciesCareGuide,
                SpeciesCareGuide.species_reference_id == Plant.species_reference_id,
            )
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
        return PlantContext(plant=row[0], guide=row[1], timezone=row.timezone)

    async def get_plant_for_delete(self, user_id: UUID, plant_id: UUID) -> Plant | None:
        return await self._session.scalar(
            select(Plant).where(Plant.id == plant_id, Plant.user_id == user_id).with_for_update()
        )

    async def get_diary(self, plant_id: UUID, diary_date: date) -> PlantDiary | None:
        return await self._session.scalar(
            select(PlantDiary).where(
                PlantDiary.plant_id == plant_id,
                PlantDiary.diary_date == diary_date,
            )
        )

    async def get_media(self, user_id: UUID, media_file_id: UUID) -> MediaFile | None:
        return await self._session.scalar(
            select(MediaFile).where(
                MediaFile.id == media_file_id,
                MediaFile.user_id == user_id,
                MediaFile.status == MediaStatus.READY.value,
                MediaFile.deleted_at.is_(None),
            )
        )

    async def list_active_events(self, plant_id: UUID) -> list[CareEvent]:
        result = await self._session.scalars(
            select(CareEvent)
            .where(
                CareEvent.plant_id == plant_id,
                CareEvent.status == CareEventStatus.SCHEDULED.value,
            )
            .order_by(CareEvent.due_date, CareEvent.created_at, CareEvent.id)
        )
        return list(result)

    async def list_today_events(self, plant_id: UUID, today: date) -> list[CareEvent]:
        result = await self._session.scalars(
            select(CareEvent)
            .where(
                CareEvent.plant_id == plant_id,
                or_(
                    and_(
                        CareEvent.status == CareEventStatus.SCHEDULED.value,
                        CareEvent.due_date == today,
                    ),
                    and_(
                        CareEvent.status == CareEventStatus.COMPLETED.value,
                        CareEvent.performed_on == today,
                    ),
                ),
            )
            .order_by(CareEvent.created_at, CareEvent.id)
        )
        return list(result)

    async def list_calendar_events(
        self, plant_id: UUID, date_from: date, date_to: date, types: set[str]
    ) -> list[CareEvent]:
        result = await self._session.scalars(
            select(CareEvent).where(
                CareEvent.plant_id == plant_id,
                CareEvent.type.in_(types),
                or_(
                    and_(
                        CareEvent.status == CareEventStatus.SCHEDULED.value,
                        CareEvent.due_date.between(date_from, date_to),
                    ),
                    and_(
                        CareEvent.status == CareEventStatus.COMPLETED.value,
                        CareEvent.performed_on.between(date_from, date_to),
                    ),
                ),
            )
        )
        return list(result)

    async def list_calendar_diaries(
        self, plant_id: UUID, date_from: date, date_to: date
    ) -> list[PlantDiary]:
        result = await self._session.scalars(
            select(PlantDiary).where(
                PlantDiary.plant_id == plant_id,
                PlantDiary.diary_date.between(date_from, date_to),
            )
        )
        return list(result)

    async def get_memo(self, plant_id: UUID, memo_date: date) -> PlantDailyMemo | None:
        return await self._session.scalar(
            select(PlantDailyMemo).where(
                PlantDailyMemo.plant_id == plant_id,
                PlantDailyMemo.memo_date == memo_date,
            )
        )

    async def count_unread_notifications(self, user_id: UUID) -> int:
        value = await self._session.scalar(
            select(func.count(Notification.id)).where(
                Notification.user_id == user_id,
                Notification.read_at.is_(None),
            )
        )
        return int(value or 0)

    async def oldest_remaining_plant_id(
        self, user_id: UUID, excluded_plant_id: UUID
    ) -> UUID | None:
        return await self._session.scalar(
            select(Plant.id)
            .where(
                Plant.user_id == user_id,
                Plant.id != excluded_plant_id,
                Plant.deleted_at.is_(None),
            )
            .order_by(Plant.created_at, Plant.id)
            .limit(1)
        )

    async def mark_plant_media_deleted(self, plant_id: UUID, user_id: UUID) -> None:
        media_ids = plant_media_ids_query(plant_id)
        now = datetime.now(UTC)
        await self._session.execute(
            update(MediaFile)
            .where(MediaFile.id.in_(media_ids), MediaFile.user_id == user_id)
            .values(status=MediaStatus.DELETED.value, deleted_at=now)
        )

    async def flush(self) -> None:
        await self._session.flush()


class PlantManagementService:
    def __init__(
        self,
        repository: PlantManagementRepository,
        storage: StorageGateway,
        *,
        download_url_expires_seconds: int,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._download_url_expires_seconds = download_url_expires_seconds

    async def list_plants(self, user_id: UUID) -> PlantListResponse:
        profile = await self._require_profile(user_id)
        plants = []
        for context in await self._repository.list_plants(user_id):
            plants.append(
                PlantListItemResponse(
                    id=context.plant.id,
                    nickname=context.plant.nickname,
                    species_reference_id=context.plant.species_reference_id,
                    species_display_name=context.guide.display_name,
                    primary_photo_url=await self._photo_url(user_id, context.plant),
                    personality_type=context.plant.personality_type,
                    color_id=context.plant.color_id,
                    hair_id=context.plant.hair_id,
                    accessory_id=context.plant.accessory_id,
                    days_together=days_together(context.plant.started_on, context.timezone),
                    is_selected=context.plant.id == profile.selected_plant_id,
                )
            )
        return PlantListResponse(plants=plants)

    async def get_plant(self, user_id: UUID, plant_id: UUID) -> PlantDetailResponse:
        context = await self._require_plant(user_id, plant_id)
        return await self._detail_response(user_id, context)

    async def update_plant(
        self, user_id: UUID, plant_id: UUID, request: PlantUpdateRequest
    ) -> PlantDetailResponse:
        context = await self._require_plant(user_id, plant_id, lock=True)
        values = request.model_dump(exclude_unset=True, exclude_none=True)
        for field, value in values.items():
            setattr(context.plant, field, value.value if hasattr(value, "value") else value)
        context.plant.updated_at = datetime.now(UTC)
        await self._repository.flush()
        return await self._detail_response(user_id, context)

    async def update_appearance(
        self, user_id: UUID, plant_id: UUID, request: PlantAppearanceUpdateRequest
    ) -> PlantDetailResponse:
        context = await self._require_plant(user_id, plant_id, lock=True)
        for field, value in request.model_dump(exclude_unset=True, exclude_none=True).items():
            setattr(context.plant, field, value)
        context.plant.updated_at = datetime.now(UTC)
        await self._repository.flush()
        return await self._detail_response(user_id, context)

    async def list_agenda(self, user_id: UUID, plant_id: UUID) -> AgendaResponse:
        context = await self._require_plant(user_id, plant_id)
        today = today_in_timezone(context.timezone)
        events = await self._repository.list_active_events(plant_id)
        return AgendaResponse(events=[agenda_event_response(event, today) for event in events])

    async def list_calendar(
        self,
        user_id: UUID,
        plant_id: UUID,
        date_from: date,
        date_to: date,
        types: str | None,
    ) -> CalendarResponse:
        context = await self._require_plant(user_id, plant_id)
        validate_calendar_range(date_from, date_to)
        selected_types = parse_calendar_types(types)
        event_types = {item.value for item in selected_types if item != CalendarItemType.CONDITION}
        events = (
            await self._repository.list_calendar_events(
                plant_id, date_from, date_to, event_types
            )
            if event_types
            else []
        )
        diaries = (
            await self._repository.list_calendar_diaries(plant_id, date_from, date_to)
            if CalendarItemType.CONDITION in selected_types
            else []
        )
        today = today_in_timezone(context.timezone)
        items = []
        for event in events:
            response = calendar_event_response(event, today)
            items.append((response.date, event.created_at, event.id, response))
        for diary in diaries:
            response = calendar_condition_response(diary)
            items.append((response.date, diary.created_at, diary.id, response))
        items.sort(key=lambda item: item[:3])
        return CalendarResponse(items=[item[3] for item in items])

    async def get_home(self, user_id: UUID, plant_id: UUID | None) -> HomeResponse:
        profile = await self._require_profile(user_id)
        unread_count = await self._repository.count_unread_notifications(user_id)
        context: PlantContext | None = None
        if plant_id is not None:
            context = await self._require_plant(user_id, plant_id)
        elif profile.selected_plant_id is not None:
            context = await self._repository.get_plant(user_id, profile.selected_plant_id)
        if context is None and plant_id is None:
            plants = await self._repository.list_plants(user_id)
            context = plants[0] if plants else None
        if context is None:
            return HomeResponse(
                plant=None,
                character=None,
                condition=None,
                today_events=[],
                daily_memo=None,
                unread_notification_count=unread_count,
            )

        today = today_in_timezone(context.timezone)
        diary = await self._repository.get_diary(context.plant.id, today)
        condition = condition_response(diary)
        memo = await self._repository.get_memo(context.plant.id, today)
        today_events = await self._repository.list_today_events(context.plant.id, today)
        return HomeResponse(
            plant=HomePlantResponse(
                id=context.plant.id,
                nickname=context.plant.nickname,
                days_together=days_together(context.plant.started_on, context.timezone),
                primary_photo_url=await self._photo_url(user_id, context.plant),
            ),
            character=HomeCharacterResponse(
                personality_type=context.plant.personality_type,
                color_id=context.plant.color_id,
                hair_id=context.plant.hair_id,
                accessory_id=context.plant.accessory_id,
                expression_level=condition.level if condition.recorded else None,
                dialogue=None,
            ),
            condition=condition,
            today_events=[agenda_event_response(event, today) for event in today_events],
            daily_memo=HomeMemoResponse(content=memo.content) if memo is not None else None,
            unread_notification_count=unread_count,
        )

    async def delete_plant(self, user_id: UUID, plant_id: UUID) -> DeletePlantResult:
        profile = await self._repository.get_profile(user_id, lock=True)
        if profile is None:
            raise AppError(
                code="USER_PROFILE_NOT_FOUND",
                message="사용자 프로필을 찾을 수 없습니다.",
                status_code=404,
            )
        plant = await self._repository.get_plant_for_delete(user_id, plant_id)
        if plant is None:
            raise AppError(
                code="PLANT_NOT_FOUND",
                message="식물을 찾을 수 없습니다.",
                status_code=404,
            )
        if plant.deleted_at is not None:
            return DeletePlantResult(enqueue_cleanup=False)

        plant.deleted_at = datetime.now(UTC)
        if profile.selected_plant_id == plant.id:
            profile.selected_plant_id = await self._repository.oldest_remaining_plant_id(
                user_id, plant.id
            )
        await self._repository.mark_plant_media_deleted(plant.id, user_id)
        await self._repository.flush()
        return DeletePlantResult(enqueue_cleanup=True)

    async def _detail_response(self, user_id: UUID, context: PlantContext) -> PlantDetailResponse:
        plant = context.plant
        guide = context.guide
        today = today_in_timezone(context.timezone)
        diary = await self._repository.get_diary(plant.id, today)
        return PlantDetailResponse(
            id=plant.id,
            nickname=plant.nickname,
            species_reference_id=plant.species_reference_id,
            species_display_name=guide.display_name,
            category=guide.category,
            scientific_name=guide.scientific_name,
            family_name=guide.family_name,
            flowering_period=guide.flowering_period,
            primary_photo_url=await self._photo_url(user_id, plant),
            started_on=plant.started_on,
            days_together=days_together(plant.started_on, context.timezone),
            place_name=plant.place_name,
            pot_type=plant.pot_type,
            placement=plant.placement,
            personality_type=plant.personality_type,
            color_id=plant.color_id,
            hair_id=plant.hair_id,
            accessory_id=plant.accessory_id,
            condition=condition_response(diary),
            created_at=plant.created_at,
            updated_at=plant.updated_at,
        )

    async def _photo_url(self, user_id: UUID, plant: Plant) -> str | None:
        if plant.primary_media_file_id is None:
            return None
        media = await self._repository.get_media(user_id, plant.primary_media_file_id)
        if media is None:
            return None
        return await self._storage.create_signed_download_url(
            media.object_path,
            expires_in=self._download_url_expires_seconds,
        )

    async def _require_profile(self, user_id: UUID) -> UserProfile:
        profile = await self._repository.get_profile(user_id)
        if profile is None:
            raise AppError(
                code="USER_PROFILE_NOT_FOUND",
                message="사용자 프로필을 찾을 수 없습니다.",
                status_code=404,
            )
        return profile

    async def _require_plant(
        self, user_id: UUID, plant_id: UUID, *, lock: bool = False
    ) -> PlantContext:
        context = await self._repository.get_plant(user_id, plant_id, lock=lock)
        if context is None:
            raise AppError(
                code="PLANT_NOT_FOUND",
                message="식물을 찾을 수 없습니다.",
                status_code=404,
            )
        return context


def days_together(started_on: date, timezone: str) -> int:
    return max((today_in_timezone(timezone) - started_on).days, 0)


def condition_response(diary: PlantDiary | None) -> PlantConditionResponse:
    if diary is None:
        return PlantConditionResponse(recorded=False, score=None, level=None)
    return PlantConditionResponse(
        recorded=True,
        score=diary.condition_score,
        level=condition_level(diary.condition_score),
    )


def care_view_status(event: CareEvent, today: date) -> CareViewStatus:
    if event.status == CareEventStatus.COMPLETED.value:
        return CareViewStatus.COMPLETED
    if event.status == CareEventStatus.CANCELLED.value:
        return CareViewStatus.CANCELLED
    if event.due_date < today:
        return CareViewStatus.OVERDUE
    if event.due_date == today:
        return CareViewStatus.TODAY
    return CareViewStatus.UPCOMING


def agenda_event_response(event: CareEvent, today: date) -> AgendaEventResponse:
    return AgendaEventResponse(
        id=event.id,
        type=event.type,
        title=event.title,
        due_date=event.due_date,
        view_status=care_view_status(event, today),
        source=event.source,
        completable=event.status == CareEventStatus.SCHEDULED.value,
    )


CALENDAR_TYPES = frozenset(CalendarItemType)


def parse_calendar_types(value: str | None) -> set[CalendarItemType]:
    if value is None:
        return set(CALENDAR_TYPES)
    values = [item.strip() for item in value.split(",")]
    if not values or any(not item for item in values):
        raise AppError(
            code="INVALID_CALENDAR_TYPES",
            message="캘린더 필터 값을 확인해 주세요.",
            status_code=422,
        )
    try:
        parsed = {CalendarItemType(item) for item in values}
    except ValueError as exc:
        raise AppError(
            code="INVALID_CALENDAR_TYPES",
            message="캘린더 필터 값을 확인해 주세요.",
            status_code=422,
        ) from exc
    return parsed


def validate_calendar_range(date_from: date, date_to: date) -> None:
    if date_from > date_to or date_to >= add_months(date_from, 3):
        raise AppError(
            code="INVALID_CALENDAR_RANGE",
            message="캘린더 조회 범위는 시작일부터 최대 3개월입니다.",
            status_code=422,
        )


def add_months(value: date, months: int) -> date:
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    return value.replace(year=year, month=month, day=min(value.day, monthrange(year, month)[1]))


def calendar_event_response(event: CareEvent, today: date) -> CalendarItemResponse:
    completed = event.status == CareEventStatus.COMPLETED.value
    display_date = event.performed_on if completed else event.due_date
    assert display_date is not None
    return CalendarItemResponse(
        id=event.id,
        date=display_date,
        type=event.type,
        status=event.status,
        view_status=care_view_status(event, today),
        title=event.title,
        source=event.source,
        condition_score=None,
        condition_level=None,
        completable=not completed,
    )


def calendar_condition_response(diary: PlantDiary) -> CalendarItemResponse:
    return CalendarItemResponse(
        id=diary.id,
        date=diary.diary_date,
        type=CalendarItemType.CONDITION,
        status=None,
        view_status=None,
        title=None,
        source=None,
        condition_score=diary.condition_score,
        condition_level=condition_level(diary.condition_score),
        completable=False,
    )
