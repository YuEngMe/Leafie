from calendar import monthrange
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from typing import Protocol
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import and_, func, literal, or_, select, union_all, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select

from app.core.errors import AppError
from app.integrations.storage import StorageGateway
from app.models.care import CareEvent, CareSchedule
from app.models.diagnosis import Diagnosis
from app.models.enums import (
    CareEventSource,
    CareEventStatus,
    CareEventType,
    CareViewStatus,
    DiagnosisStatus,
    ExpressionType,
    MediaStatus,
    PersonalityType,
    WaterRecommendationSource,
)
from app.models.letter import Letter
from app.models.media import MediaFile, SpeciesIdentification
from app.models.notification import Notification
from app.models.plant import Plant, PlantDiary, PlantPersonalityChange, SpeciesCareGuide
from app.models.sensor import PlantSensorEvent
from app.models.user import UserProfile
from app.schemas.plant import (
    AgendaEventResponse,
    AgendaResponse,
    CalendarItemResponse,
    CalendarItemType,
    CalendarResponse,
    HomeBackgroundPhase,
    HomeDialogueEventResponse,
    HomeDialogueKey,
    HomePlantResponse,
    HomeResponse,
    HomeRoomResponse,
    PlantAppearanceUpdateRequest,
    PlantDetailResponse,
    PlantListItemResponse,
    PlantListResponse,
    PlantUpdateRequest,
)
from app.schemas.sensor import SensorLevel
from app.services.letter import visible_letters
from app.services.plant import next_recurring_due_date, today_in_timezone
from app.services.sensor_assessment import SensorAssessmentService


@dataclass(frozen=True, slots=True)
class PlantContext:
    plant: Plant
    guide: SpeciesCareGuide
    timezone: str


@dataclass(frozen=True, slots=True)
class DeletePlantResult:
    enqueue_cleanup: bool


@dataclass(frozen=True, slots=True)
class HomeDialogueEvent:
    event_id: UUID
    dialogue_key: HomeDialogueKey
    occurred_at: datetime


@dataclass(frozen=True, slots=True)
class DiagnosisPromptState:
    latest_status: str | None
    last_completed_at: datetime | None


HOME_DIALOGUES: dict[HomeDialogueKey, dict[PersonalityType, str]] = {
    HomeDialogueKey.NORMAL: {
        PersonalityType.OUTGOING: "오늘도 같이 놀자!",
        PersonalityType.CHIC: "됐어. 그냥 있어.",
        PersonalityType.CUTE: "오늘은 뭐 하고 놀까?",
        PersonalityType.INTROVERTED: "와줬네… 사실 조금 기다렸어.",
        PersonalityType.CRUSH: "오늘도 네 생각만 했어….",
        PersonalityType.CHUNGCHEONG: "기다리고 있었구먼유.",
    },
    HomeDialogueKey.WATERING_COMPLETED: {
        PersonalityType.OUTGOING: "물 고마워!",
        PersonalityType.CHIC: "물 줬네. 됐어.",
        PersonalityType.CUTE: "헤헤, 물 먹으니까 기분이 좋아졌어!",
        PersonalityType.INTROVERTED: "물 줘서 고마워… 이제 목 안 말라.",
        PersonalityType.CRUSH: "네가 준 물이라 더 달아..ㅎ",
        PersonalityType.CHUNGCHEONG: "아이고, 물 잘 먹었슈.",
    },
    HomeDialogueKey.LIGHT_LOW: {
        PersonalityType.OUTGOING: "나 햇빛 보고 싶어!",
        PersonalityType.CHIC: "좀 어둡네. 신경 쓰이게.",
        PersonalityType.CUTE: "나 햇빛 구경하고 싶은데 같이 가줄래?",
        PersonalityType.INTROVERTED: "저기… 조금만 더 밝은 곳으로 가도 될까?",
        PersonalityType.CRUSH: "네 옆이면 어두워도 괜찮은데… 그래도 햇빛 좀…",
        PersonalityType.CHUNGCHEONG: "햇빛이 영 부족허구먼유…",
    },
    HomeDialogueKey.LIGHT_HIGH: {
        PersonalityType.OUTGOING: "햇빛이 너무 뜨거워!",
        PersonalityType.CHIC: "너무 밝아. 눈부시게.",
        PersonalityType.CUTE: "나 조금 뜨거운 것 같아!",
        PersonalityType.INTROVERTED: "햇빛이 조금 따가워… 그늘에서 쉬면 안 될까?",
        PersonalityType.CRUSH: "너무 뜨거워… 네가 그늘 되어주면 안 돼?",
        PersonalityType.CHUNGCHEONG: "햇빛이 좀 세구먼유…",
    },
    HomeDialogueKey.LIGHT_OPTIMAL: {
        PersonalityType.OUTGOING: "여기 자리 완전 마음에 들어!",
        PersonalityType.CHIC: "이 정도면 뭐, 나쁘지 않네.",
        PersonalityType.CUTE: "나 여기 마음에 들어!",
        PersonalityType.INTROVERTED: "여기 햇살 좋다… 나 여기 있어도 되지?",
        PersonalityType.CRUSH: "이 햇빛, 너랑 같이 쬐고 싶다…",
        PersonalityType.CHUNGCHEONG: "햇빛 딱 좋구먼유. 이 정도면 됐슈.",
    },
    HomeDialogueKey.SOIL_MOISTURE_LOW: {
        PersonalityType.OUTGOING: "목말라~!",
        PersonalityType.CHIC: "건조해. 티는 안 낼 거지만.",
        PersonalityType.CUTE: "나 물 주는 거 까먹은 건 아니지…?",
        PersonalityType.INTROVERTED: "나… 목이 조금 마른 것 같아. 물 줄 수 있어?",
        PersonalityType.CRUSH: "목말라… 근데 네 관심이 더 고파",
        PersonalityType.CHUNGCHEONG: "공기가 좀 메마른디유…",
    },
    HomeDialogueKey.SOIL_MOISTURE_HIGH: {
        PersonalityType.OUTGOING: "물은 그만줘도 돼!",
        PersonalityType.CHIC: "축축해. 별로야.",
        PersonalityType.CUTE: "촉촉한 건 좋은데… 이건 조금 많아!",
        PersonalityType.INTROVERTED: "물은 지금 충분해… 조금만 쉬었다 마실게.",
        PersonalityType.CRUSH: "물은 됐고, 네 마음이나 더 줘!",
        PersonalityType.CHUNGCHEONG: "습기가 좀 많구먼유…",
    },
    HomeDialogueKey.DIARY_PROMPT: {
        PersonalityType.OUTGOING: "오늘 기록 하나 남겨줘",
        PersonalityType.CHIC: "쓰든 말든 네 맘인데... 궁금하긴 해.",
        PersonalityType.CUTE: "오늘의 나도 기록해줄 거지?",
        PersonalityType.INTROVERTED: "오늘은 어떻게 지냈어…? 적어 주면 읽고 싶어.",
        PersonalityType.CRUSH: "오늘 네 하루, 나한테만 몰래 알려줄래?",
        PersonalityType.CHUNGCHEONG: "나한테도 오늘 이야기 좀 해주셔유.",
    },
    HomeDialogueKey.DIAGNOSIS_PROMPT: {
        PersonalityType.OUTGOING: "잠깐! 내 상태 한 번 봐줄래?",
        PersonalityType.CHIC: "나 한번 진단해봐. 딱히 걱정되는 거 아니고 그냥.",
        PersonalityType.CUTE: "내 상태가 궁금해! 나 한번 살펴봐줘~",
        PersonalityType.INTROVERTED: "저기… 내 모습 한 번만 살펴봐 줄래?",
        PersonalityType.CRUSH: "내 상태, 너한테만 보여주고 싶어…",
        PersonalityType.CHUNGCHEONG: "요새 내 상태가 좀 궁금허시쥬? 한번 봐주셔유.",
    },
    HomeDialogueKey.LETTER_SENT: {
        PersonalityType.OUTGOING: "네 마음 잘 받았어! 내 답장도 받아줘!",
        PersonalityType.CHIC: "일기 읽었어. 답장 보낸다, 별거 아니지만.",
        PersonalityType.CUTE: "이거 소중하게 간직할게! 내 이야기도 들어줘!",
        PersonalityType.INTROVERTED: "답장 써 봤어… 조금 쑥스럽지만 읽어 줄래?",
        PersonalityType.CRUSH: "네 마음 읽었어… 나도 답장에 진심 담았어!",
        PersonalityType.CHUNGCHEONG: "오늘 이야기도 잘 봤슈. 내 답장도 읽어봐유.",
    },
    HomeDialogueKey.DIARY_RECEIVED: {
        PersonalityType.OUTGOING: "오늘 이야기도 잘 받았어!",
        PersonalityType.CHIC: "오늘도 썼네. 나쁘지 않아.",
        PersonalityType.CUTE: "오늘의 이야기를 들려줘서 고마워",
        PersonalityType.INTROVERTED: "네 이야기 잘 받았어… 나한테 들려줘서 고마워.",
        PersonalityType.CRUSH: "오늘 이야기, 소중히 간직할게!",
        PersonalityType.CHUNGCHEONG: "당신 이야기를 들으니 나도 기분이 좋아졌구먼유.",
    },
}


def home_dialogue(personality_type: str, dialogue_key: HomeDialogueKey) -> str:
    return HOME_DIALOGUES[dialogue_key][PersonalityType(personality_type)]


HOME_DIALOGUE_PRIORITY = {
    HomeDialogueKey.WATERING_COMPLETED: 0,
    HomeDialogueKey.DIARY_RECEIVED: 1,
    HomeDialogueKey.SOIL_MOISTURE_LOW: 2,
    HomeDialogueKey.SOIL_MOISTURE_HIGH: 2,
    HomeDialogueKey.LETTER_SENT: 3,
    HomeDialogueKey.LIGHT_LOW: 4,
    HomeDialogueKey.LIGHT_HIGH: 4,
    HomeDialogueKey.LIGHT_OPTIMAL: 4,
}


def plant_media_ids_query(plant_id: UUID) -> Select:
    media_ids = union_all(
        select(Plant.primary_media_file_id.label("media_id")).where(Plant.id == plant_id),
        select(SpeciesIdentification.media_file_id.label("media_id"))
        .join(Plant, Plant.species_identification_id == SpeciesIdentification.id)
        .where(Plant.id == plant_id),
        select(PlantDiary.media_file_id.label("media_id")).where(PlantDiary.plant_id == plant_id),
        select(Diagnosis.media_file_id.label("media_id")).where(Diagnosis.plant_id == plant_id),
    ).subquery()
    return select(media_ids.c.media_id).where(media_ids.c.media_id.is_not(None)).distinct()


class PlantManagementRepository(Protocol):
    async def get_profile(self, user_id: UUID, *, lock: bool = False) -> UserProfile | None: ...

    async def list_plants(self, user_id: UUID) -> list[PlantContext]: ...

    async def get_plant(
        self, user_id: UUID, plant_id: UUID, *, lock: bool = False
    ) -> PlantContext | None: ...

    async def get_plant_for_delete(self, user_id: UUID, plant_id: UUID) -> Plant | None: ...

    async def get_media(self, user_id: UUID, media_file_id: UUID) -> MediaFile | None: ...

    async def list_active_events(self, plant_id: UUID) -> list[CareEvent]: ...

    async def list_today_events(self, plant_id: UUID, today: date) -> list[CareEvent]: ...

    async def list_home_dialogue_events(
        self, plant_id: UUID, started_at: datetime, ended_at: datetime
    ) -> list[HomeDialogueEvent]: ...

    async def diary_exists_on(self, plant_id: UUID, diary_date: date) -> bool: ...

    async def diagnosis_prompt_state(self, plant_id: UUID) -> DiagnosisPromptState: ...

    async def list_calendar_events(
        self, plant_id: UUID, date_from: date, date_to: date, types: set[str]
    ) -> list[CareEvent]: ...

    async def latest_completed_dates(self, plant_id: UUID) -> dict[str, date]: ...

    async def completed_events_for_update(
        self, plant_id: UUID, care_type: CareEventType
    ) -> list[CareEvent]: ...

    async def get_schedule(
        self, plant_id: UUID, care_type: CareEventType, *, lock: bool = False
    ) -> CareSchedule | None: ...

    async def get_scheduled_event_for_update(self, schedule_id: UUID) -> CareEvent | None: ...

    async def count_unread_notifications(self, user_id: UUID) -> int: ...

    async def count_unread_letters(self, user_id: UUID) -> int: ...

    async def oldest_remaining_plant_id(
        self, user_id: UUID, excluded_plant_id: UUID
    ) -> UUID | None: ...

    async def mark_plant_media_deleted(self, plant_id: UUID, user_id: UUID) -> None: ...

    def add_personality_change(self, change: PlantPersonalityChange) -> None: ...

    async def add(self, instance: object) -> None: ...

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

    async def list_home_dialogue_events(
        self, plant_id: UUID, started_at: datetime, ended_at: datetime
    ) -> list[HomeDialogueEvent]:
        watering = select(
            CareEvent.id.label("event_id"),
            literal(HomeDialogueKey.WATERING_COMPLETED.value).label("dialogue_key"),
            CareEvent.recorded_at.label("occurred_at"),
        ).where(
            CareEvent.plant_id == plant_id,
            CareEvent.type == CareEventType.WATERING.value,
            CareEvent.status == CareEventStatus.COMPLETED.value,
            CareEvent.recorded_at >= started_at,
            CareEvent.recorded_at < ended_at,
        )
        diaries = select(
            PlantDiary.id.label("event_id"),
            literal(HomeDialogueKey.DIARY_RECEIVED.value).label("dialogue_key"),
            PlantDiary.created_at.label("occurred_at"),
        ).where(
            PlantDiary.plant_id == plant_id,
            PlantDiary.created_at >= started_at,
            PlantDiary.created_at < ended_at,
        )
        letters = select(
            Letter.id.label("event_id"),
            literal(HomeDialogueKey.LETTER_SENT.value).label("dialogue_key"),
            Letter.published_at.label("occurred_at"),
        ).where(
            Letter.plant_id == plant_id,
            Letter.status == "COMPLETED",
            Letter.deleted_at.is_(None),
            Letter.published_at >= started_at,
            Letter.published_at < ended_at,
            Letter.published_at <= func.now(),
        )
        sensor_events = select(
            PlantSensorEvent.id.label("event_id"),
            PlantSensorEvent.type.label("dialogue_key"),
            PlantSensorEvent.occurred_at.label("occurred_at"),
        ).where(
            PlantSensorEvent.plant_id == plant_id,
            PlantSensorEvent.occurred_at >= started_at,
            PlantSensorEvent.occurred_at < ended_at,
        )
        rows = (
            await self._session.execute(union_all(watering, diaries, letters, sensor_events))
        ).all()
        sensor_keys = {"SOIL_LOW": "SOIL_MOISTURE_LOW", "SOIL_HIGH": "SOIL_MOISTURE_HIGH"}
        return [
            HomeDialogueEvent(
                event_id=row.event_id,
                dialogue_key=HomeDialogueKey(sensor_keys.get(row.dialogue_key, row.dialogue_key)),
                occurred_at=row.occurred_at,
            )
            for row in rows
        ]

    async def diary_exists_on(self, plant_id: UUID, diary_date: date) -> bool:
        return (
            await self._session.scalar(
                select(PlantDiary.id)
                .where(
                    PlantDiary.plant_id == plant_id,
                    PlantDiary.diary_date == diary_date,
                )
                .limit(1)
            )
            is not None
        )

    async def diagnosis_prompt_state(self, plant_id: UUID) -> DiagnosisPromptState:
        latest_status = (
            select(Diagnosis.status)
            .where(Diagnosis.plant_id == plant_id)
            .order_by(Diagnosis.created_at.desc(), Diagnosis.id.desc())
            .limit(1)
            .scalar_subquery()
        )
        last_completed_at = (
            select(func.max(Diagnosis.completed_at))
            .where(
                Diagnosis.plant_id == plant_id,
                Diagnosis.status == DiagnosisStatus.COMPLETED.value,
            )
            .scalar_subquery()
        )
        row = (
            await self._session.execute(
                select(
                    latest_status.label("latest_status"),
                    last_completed_at.label("last_completed_at"),
                )
            )
        ).one()
        return DiagnosisPromptState(
            latest_status=row.latest_status,
            last_completed_at=row.last_completed_at,
        )

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

    async def latest_completed_dates(self, plant_id: UUID) -> dict[str, date]:
        rows = await self._session.execute(
            select(CareEvent.type, func.max(CareEvent.performed_on).label("performed_on"))
            .where(
                CareEvent.plant_id == plant_id,
                CareEvent.status == CareEventStatus.COMPLETED.value,
                CareEvent.type.in_([CareEventType.WATERING.value, CareEventType.REPOTTING.value]),
            )
            .group_by(CareEvent.type)
        )
        return {row.type: row.performed_on for row in rows if row.performed_on is not None}

    async def completed_events_for_update(
        self, plant_id: UUID, care_type: CareEventType
    ) -> list[CareEvent]:
        result = await self._session.scalars(
            select(CareEvent)
            .where(
                CareEvent.plant_id == plant_id,
                CareEvent.type == care_type.value,
                CareEvent.status == CareEventStatus.COMPLETED.value,
            )
            .order_by(
                CareEvent.performed_on.desc(),
                CareEvent.recorded_at.desc(),
                CareEvent.id.desc(),
            )
            .limit(2)
            .with_for_update()
        )
        return list(result)

    async def get_schedule(
        self, plant_id: UUID, care_type: CareEventType, *, lock: bool = False
    ) -> CareSchedule | None:
        statement = select(CareSchedule).where(
            CareSchedule.plant_id == plant_id,
            CareSchedule.type == care_type.value,
        )
        if lock:
            statement = statement.with_for_update()
        return await self._session.scalar(statement)

    async def get_scheduled_event_for_update(self, schedule_id: UUID) -> CareEvent | None:
        return await self._session.scalar(
            select(CareEvent)
            .where(
                CareEvent.schedule_id == schedule_id,
                CareEvent.status == CareEventStatus.SCHEDULED.value,
            )
            .with_for_update()
        )

    async def count_unread_notifications(self, user_id: UUID) -> int:
        value = await self._session.scalar(
            select(func.count(Notification.id)).where(
                Notification.user_id == user_id,
                Notification.read_at.is_(None),
            )
        )
        return int(value or 0)

    async def count_unread_letters(self, user_id: UUID) -> int:
        statement = visible_letters(user_id).where(Letter.read_at.is_(None))
        value = await self._session.scalar(select(func.count()).select_from(statement.subquery()))
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

    def add_personality_change(self, change: PlantPersonalityChange) -> None:
        self._session.add(change)

    async def add(self, instance: object) -> None:
        self._session.add(instance)
        await self._session.flush()

    async def flush(self) -> None:
        await self._session.flush()


class PlantManagementService:
    def __init__(
        self,
        repository: PlantManagementRepository,
        storage: StorageGateway,
        *,
        download_url_expires_seconds: int,
        assessments: SensorAssessmentService | None = None,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._download_url_expires_seconds = download_url_expires_seconds
        self._assessments = assessments

    async def list_plants(self, user_id: UUID) -> PlantListResponse:
        await self._require_profile(user_id)
        plants = []
        for context in await self._repository.list_plants(user_id):
            plants.append(
                PlantListItemResponse(
                    id=context.plant.id,
                    nickname=context.plant.nickname,
                    species_reference_id=context.plant.species_reference_id,
                    species_display_name=context.guide.display_name,
                    personality_type=context.plant.personality_type,
                    body_id=context.plant.body_id,
                    color_id=context.plant.color_id,
                    hair_id=context.plant.hair_id,
                    expression_id=context.plant.expression_id,
                    primary_photo_url=await self._photo_url(user_id, context.plant),
                    started_on=context.plant.started_on,
                )
            )
        return PlantListResponse(items=plants)

    async def get_plant(self, user_id: UUID, plant_id: UUID) -> PlantDetailResponse:
        context = await self._require_plant(user_id, plant_id)
        return await self._detail_response(user_id, context)

    async def update_plant(
        self, user_id: UUID, plant_id: UUID, request: PlantUpdateRequest
    ) -> PlantDetailResponse:
        context = await self._require_plant(user_id, plant_id, lock=True)
        values = request.model_dump(exclude_unset=True, exclude_none=True)
        care_date_fields = {
            CareEventType.WATERING: values.pop("last_watered_on", None),
            CareEventType.REPOTTING: values.pop("last_repotted_on", None),
        }
        requested_personality = values.get("personality_type")
        if requested_personality is not None:
            next_personality = requested_personality.value
            if next_personality != context.plant.personality_type:
                self._repository.add_personality_change(
                    PlantPersonalityChange(
                        plant_id=context.plant.id,
                        previous_personality_type=context.plant.personality_type,
                        new_personality_type=next_personality,
                    )
                )
        for field, value in values.items():
            setattr(context.plant, field, value.value if hasattr(value, "value") else value)
        now = datetime.now(UTC)
        today = today_in_timezone(context.timezone)
        for care_type, performed_on in care_date_fields.items():
            if performed_on is not None:
                await self._correct_latest_care_date(
                    context,
                    care_type,
                    performed_on,
                    today=today,
                    now=now,
                )
        context.plant.updated_at = now
        await self._repository.flush()
        return await self._detail_response(user_id, context)

    async def update_appearance(
        self, user_id: UUID, plant_id: UUID, request: PlantAppearanceUpdateRequest
    ) -> PlantDetailResponse:
        context = await self._require_plant(user_id, plant_id, lock=True)
        for field, value in request.model_dump(
            mode="json", exclude_unset=True, exclude_none=True
        ).items():
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
        event_types = {item.value for item in selected_types}
        events = await self._repository.list_calendar_events(
            plant_id, date_from, date_to, event_types
        )
        today = today_in_timezone(context.timezone)
        items = []
        for event in events:
            response = calendar_event_response(event, today)
            items.append((response.date, event.created_at, event.id, response))
        items.sort(key=lambda item: item[:3])
        return CalendarResponse(items=[item[3] for item in items])

    async def get_home(
        self,
        user_id: UUID,
        plant_id: UUID | None,
        *,
        now: datetime | None = None,
    ) -> HomeResponse:
        profile = await self._require_profile(user_id)
        unread_notification_count = await self._repository.count_unread_notifications(user_id)
        unread_letter_count = await self._repository.count_unread_letters(user_id)
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
                room=None,
                today_events=[],
                unread_letter_count=unread_letter_count,
                unread_notification_count=unread_notification_count,
            )

        timezone = resolve_timezone(context.timezone)
        local_now = (now or datetime.now(UTC)).astimezone(timezone)
        today = local_now.date()
        day_started_at = datetime.combine(today, time.min, tzinfo=timezone).astimezone(UTC)
        day_ended_at = datetime.combine(
            today + timedelta(days=1), time.min, tzinfo=timezone
        ).astimezone(UTC)
        today_events = await self._repository.list_today_events(context.plant.id, today)
        dialogue_events = await self._repository.list_home_dialogue_events(
            context.plant.id, day_started_at, day_ended_at
        )
        sensor = (
            await self._assessments.read(context.plant.id, now=local_now)
            if self._assessments is not None
            else None
        )
        active_sensor_keys = set()
        if sensor is not None:
            for state, mapping in (
                (
                    sensor.soil.state,
                    {
                        SensorLevel.LOW: HomeDialogueKey.SOIL_MOISTURE_LOW,
                        SensorLevel.HIGH: HomeDialogueKey.SOIL_MOISTURE_HIGH,
                    },
                ),
                (
                    sensor.light.state,
                    {
                        SensorLevel.LOW: HomeDialogueKey.LIGHT_LOW,
                        SensorLevel.HIGH: HomeDialogueKey.LIGHT_HIGH,
                    },
                ),
            ):
                if state in mapping:
                    active_sensor_keys.add(mapping[state])
            sensor_keys = {
                HomeDialogueKey.SOIL_MOISTURE_LOW,
                HomeDialogueKey.SOIL_MOISTURE_HIGH,
                HomeDialogueKey.LIGHT_LOW,
                HomeDialogueKey.LIGHT_HIGH,
            }
            dialogue_events = [
                event
                for event in dialogue_events
                if event.dialogue_key not in sensor_keys or event.dialogue_key in active_sensor_keys
            ]
        dialogue_events.sort(
            key=lambda item: (
                HOME_DIALOGUE_PRIORITY[item.dialogue_key],
                -item.occurred_at.timestamp(),
            )
        )
        has_diary_today = await self._repository.diary_exists_on(context.plant.id, today)
        diagnosis_state = await self._repository.diagnosis_prompt_state(context.plant.id)
        if active_sensor_keys:
            dialogue_key = min(active_sensor_keys, key=HOME_DIALOGUE_PRIORITY.__getitem__)
        elif local_now.hour >= 18 and not has_diary_today:
            dialogue_key = HomeDialogueKey.DIARY_PROMPT
        elif should_prompt_diagnosis(context.plant, diagnosis_state, local_now):
            dialogue_key = HomeDialogueKey.DIAGNOSIS_PROMPT
        elif sensor is not None and sensor.light.state == SensorLevel.OK:
            dialogue_key = HomeDialogueKey.LIGHT_OPTIMAL
        else:
            dialogue_key = HomeDialogueKey.NORMAL
        return HomeResponse(
            plant=HomePlantResponse(
                id=context.plant.id,
                nickname=context.plant.nickname,
                started_on=context.plant.started_on,
                days_together=days_together(context.plant.started_on, context.timezone),
                personality_type=context.plant.personality_type,
                body_id=context.plant.body_id,
                color_id=context.plant.color_id,
                hair_id=context.plant.hair_id,
                expression_id=(
                    ExpressionType.SAD
                    if active_sensor_keys
                    else ExpressionType.HAPPY
                    if sensor is not None
                    and sensor.soil.state == sensor.light.state == SensorLevel.OK
                    else ExpressionType.DEFAULT
                    if sensor is not None
                    else context.plant.expression_id
                ),
                primary_photo_url=await self._photo_url(user_id, context.plant),
            ),
            room=HomeRoomResponse(
                sensor=sensor,
                background_phase=home_background_phase(context.timezone, now=local_now),
                dialogue_key=dialogue_key,
                dialogue=home_dialogue(context.plant.personality_type, dialogue_key),
                dialogue_queue=[
                    HomeDialogueEventResponse(
                        event_id=str(event.event_id),
                        dialogue_key=event.dialogue_key,
                        dialogue=home_dialogue(context.plant.personality_type, event.dialogue_key),
                        occurred_at=event.occurred_at,
                    )
                    for event in dialogue_events
                ],
            ),
            today_events=[agenda_event_response(event, today) for event in today_events],
            unread_letter_count=unread_letter_count,
            unread_notification_count=unread_notification_count,
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
        if plant is None or plant.deleted_at is not None:
            # hard delete 이후 재요청과 soft delete 중복 요청 모두 204로 멱등 처리한다.
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
        care_dates = await self._repository.latest_completed_dates(plant.id)
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
            last_watered_on=care_dates.get(CareEventType.WATERING.value),
            last_repotted_on=care_dates.get(CareEventType.REPOTTING.value),
            place_name=plant.place_name,
            personality_type=plant.personality_type,
            body_id=plant.body_id,
            color_id=plant.color_id,
            hair_id=plant.hair_id,
            expression_id=plant.expression_id,
            created_at=plant.created_at,
            updated_at=plant.updated_at,
        )

    async def _correct_latest_care_date(
        self,
        context: PlantContext,
        care_type: CareEventType,
        performed_on: date,
        *,
        today: date,
        now: datetime,
    ) -> None:
        if performed_on > today:
            raise AppError(
                code="FUTURE_DATE_NOT_ALLOWED",
                message="미래 날짜는 입력할 수 없습니다.",
                status_code=400,
            )

        interval_days = (
            context.guide.default_watering_interval_days
            if care_type == CareEventType.WATERING
            else context.guide.default_repotting_interval_days
        )
        schedule = await self._repository.get_schedule(context.plant.id, care_type)
        scheduled_event = (
            await self._repository.get_scheduled_event_for_update(schedule.id)
            if schedule is not None
            else None
        )
        if schedule is not None:
            schedule = await self._repository.get_schedule(context.plant.id, care_type, lock=True)

        completed_events = await self._repository.completed_events_for_update(
            context.plant.id, care_type
        )
        previous_performed_on = (
            completed_events[1].performed_on if len(completed_events) > 1 else None
        )
        if previous_performed_on is not None and performed_on < previous_performed_on:
            raise AppError(
                code="CARE_DATE_BEFORE_PREVIOUS_EVENT",
                message="이전 완료 기록보다 과거 날짜로 변경할 수 없습니다.",
                status_code=409,
            )

        if schedule is None and interval_days is not None:
            schedule = CareSchedule(
                id=uuid4(),
                plant_id=context.plant.id,
                type=care_type.value,
                interval_days=interval_days,
                next_due_date=next_recurring_due_date(performed_on, interval_days, today),
                recommended_water_min_ml=(
                    context.guide.recommended_water_min_ml
                    if care_type == CareEventType.WATERING
                    else None
                ),
                recommended_water_max_ml=(
                    context.guide.recommended_water_max_ml
                    if care_type == CareEventType.WATERING
                    else None
                ),
                recommendation_source=(
                    WaterRecommendationSource.SPECIES_GUIDE.value
                    if care_type == CareEventType.WATERING
                    and context.guide.recommended_water_min_ml is not None
                    and context.guide.recommended_water_max_ml is not None
                    else None
                ),
                enabled=True,
                created_at=now,
                updated_at=now,
            )
            await self._repository.add(schedule)

        if completed_events:
            completed_event = completed_events[0]
            completed_event.performed_on = performed_on
            completed_event.schedule_id = schedule.id if schedule is not None else None
            completed_event.updated_at = now
        else:
            await self._repository.add(
                CareEvent(
                    id=uuid4(),
                    plant_id=context.plant.id,
                    schedule_id=schedule.id if schedule is not None else None,
                    type=care_type.value,
                    status=CareEventStatus.COMPLETED.value,
                    source=CareEventSource.USER_CREATED.value,
                    due_date=performed_on,
                    performed_on=performed_on,
                    recorded_at=now,
                    created_at=now,
                    updated_at=now,
                )
            )

        if schedule is None or interval_days is None:
            return
        next_due_date = next_recurring_due_date(performed_on, interval_days, today)
        schedule.next_due_date = next_due_date
        schedule.enabled = True
        schedule.updated_at = now
        if scheduled_event is None:
            await self._repository.add(
                CareEvent(
                    id=uuid4(),
                    plant_id=context.plant.id,
                    schedule_id=schedule.id,
                    type=care_type.value,
                    status=CareEventStatus.SCHEDULED.value,
                    source=CareEventSource.AUTO_SCHEDULE.value,
                    due_date=next_due_date,
                    created_at=now,
                    updated_at=now,
                )
            )
        else:
            scheduled_event.due_date = next_due_date
            scheduled_event.updated_at = now

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
    return max((today_in_timezone(timezone) - started_on).days + 1, 1)


def home_background_phase(
    timezone_name: str, *, now: datetime | None = None
) -> HomeBackgroundPhase:
    timezone = resolve_timezone(timezone_name)
    local_time = (now or datetime.now(UTC)).astimezone(timezone).time()
    return HomeBackgroundPhase.DAY if 6 <= local_time.hour < 18 else HomeBackgroundPhase.NIGHT


def resolve_timezone(timezone_name: str) -> ZoneInfo:
    try:
        return ZoneInfo(timezone_name)
    except (ZoneInfoNotFoundError, ValueError):
        return ZoneInfo("Asia/Seoul")


def should_prompt_diagnosis(
    plant: Plant,
    state: DiagnosisPromptState,
    local_now: datetime,
) -> bool:
    if state.latest_status == DiagnosisStatus.NEEDS_RETAKE.value:
        return True
    if state.latest_status in {
        DiagnosisStatus.PENDING.value,
        DiagnosisStatus.PROCESSING.value,
    }:
        return False

    created_at = plant.created_at
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=UTC)
    if (local_now.date() - created_at.astimezone(local_now.tzinfo).date()).days < 7:
        return False

    completed_at = state.last_completed_at
    if completed_at is None:
        return True
    if completed_at.tzinfo is None:
        completed_at = completed_at.replace(tzinfo=UTC)
    return local_now - completed_at.astimezone(local_now.tzinfo) >= timedelta(days=14)


def care_view_status(event: CareEvent, today: date) -> CareViewStatus:
    if event.status == CareEventStatus.COMPLETED.value:
        return CareViewStatus.COMPLETED
    if event.due_date < today:
        return CareViewStatus.OVERDUE
    if event.due_date == today:
        return CareViewStatus.TODAY
    return CareViewStatus.UPCOMING


def agenda_event_response(event: CareEvent, today: date) -> AgendaEventResponse:
    return AgendaEventResponse(
        id=event.id,
        care_type=event.type,
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
        care_type=event.type,
        status=event.status,
        view_status=care_view_status(event, today),
        source=event.source,
        completable=not completed,
    )
