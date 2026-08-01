import hashlib
import json
from datetime import UTC, date, datetime, timedelta
from typing import Protocol
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.care import CareEvent, CareSchedule
from app.models.chat import AIConversation
from app.models.enums import (
    CareEventSource,
    CareEventStatus,
    CareEventType,
    CareScheduleType,
    MediaPurpose,
    MediaStatus,
    RepottingHistoryStatus,
    SpeciesIdentificationStatus,
    SpeciesSelectionMethod,
    WaterRecommendationSource,
)
from app.models.media import MediaFile, SpeciesIdentification
from app.models.plant import Plant, SpeciesCareGuide
from app.models.user import UserProfile
from app.schemas.plant import PlantCreateRequest, PlantCreateResponse


class PlantRegistrationRepository(Protocol):
    async def get_profile_for_update(self, user_id: UUID) -> UserProfile | None: ...

    async def get_by_client_registration_id(
        self,
        user_id: UUID,
        client_registration_id: UUID,
    ) -> Plant | None: ...

    async def get_active_guide(self, species_reference_id: str) -> SpeciesCareGuide | None: ...

    async def get_identification_for_update(
        self, identification_id: UUID, user_id: UUID
    ) -> SpeciesIdentification | None: ...

    async def identification_is_used(self, identification_id: UUID) -> bool: ...

    async def get_media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None: ...

    async def add_registration(self, *entities: object) -> None: ...

    async def flush(self) -> None: ...


class SQLAlchemyPlantRegistrationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_profile_for_update(self, user_id: UUID) -> UserProfile | None:
        return await self._session.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id).with_for_update()
        )

    async def get_by_client_registration_id(
        self,
        user_id: UUID,
        client_registration_id: UUID,
    ) -> Plant | None:
        return await self._session.scalar(
            select(Plant).where(
                Plant.user_id == user_id,
                Plant.client_registration_id == client_registration_id,
            )
        )

    async def get_active_guide(self, species_reference_id: str) -> SpeciesCareGuide | None:
        return await self._session.scalar(
            select(SpeciesCareGuide).where(
                SpeciesCareGuide.species_reference_id == species_reference_id,
                SpeciesCareGuide.active.is_(True),
            )
        )

    async def get_identification_for_update(
        self, identification_id: UUID, user_id: UUID
    ) -> SpeciesIdentification | None:
        return await self._session.scalar(
            select(SpeciesIdentification)
            .where(
                SpeciesIdentification.id == identification_id,
                SpeciesIdentification.user_id == user_id,
            )
            .with_for_update()
        )

    async def identification_is_used(self, identification_id: UUID) -> bool:
        return (
            await self._session.scalar(
                select(Plant.id).where(Plant.species_identification_id == identification_id)
            )
            is not None
        )

    async def get_media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None:
        return await self._session.scalar(
            select(MediaFile).where(
                MediaFile.id == media_file_id,
                MediaFile.user_id == user_id,
                MediaFile.deleted_at.is_(None),
            )
        )

    async def add_registration(self, *entities: object) -> None:
        self._session.add_all(entities)
        await self._session.flush()

    async def flush(self) -> None:
        await self._session.flush()


class PlantRegistrationService:
    def __init__(self, repository: PlantRegistrationRepository) -> None:
        self._repository = repository

    async def create_plant(
        self,
        user_id: UUID,
        request: PlantCreateRequest,
    ) -> PlantCreateResponse:
        profile = await self._repository.get_profile_for_update(user_id)
        if profile is None:
            raise AppError(
                code="USER_PROFILE_NOT_FOUND",
                message="사용자 프로필을 찾을 수 없습니다.",
                status_code=404,
            )
        if profile.profile_completed_at is None:
            raise AppError(
                code="PROFILE_INCOMPLETE",
                message="닉네임 설정을 완료해 주세요.",
                status_code=409,
            )

        request_hash = registration_request_hash(request)
        existing_plant = await self._repository.get_by_client_registration_id(
            user_id,
            request.client_registration_id,
        )
        if existing_plant is not None:
            if existing_plant.registration_request_hash != request_hash:
                raise AppError(
                    code="PLANT_REGISTRATION_ID_REUSED",
                    message="이미 다른 식물 등록에 사용한 client_registration_id입니다.",
                    status_code=409,
                )
            return PlantCreateResponse(
                id=existing_plant.id,
                created_at=existing_plant.created_at,
            )

        guide = await self._repository.get_active_guide(request.species_reference_id)
        if guide is None:
            raise AppError(
                code="SPECIES_NOT_FOUND",
                message="지원하는 식물을 찾을 수 없습니다.",
                status_code=404,
            )
        if guide.default_watering_interval_days is None:
            raise AppError(
                code="SPECIES_CARE_GUIDE_INCOMPLETE",
                message="선택한 식물의 물주기 정보를 확인할 수 없습니다.",
                status_code=409,
            )

        today = today_in_timezone(profile.timezone)
        self._validate_dates(request, today)
        identification = await self._validate_identification(user_id, request)

        now = datetime.now(UTC)
        plant = Plant(
            id=uuid4(),
            user_id=user_id,
            client_registration_id=request.client_registration_id,
            registration_request_hash=request_hash,
            species_reference_id=guide.species_reference_id,
            species_identification_id=(identification.id if identification is not None else None),
            primary_media_file_id=request.primary_media_file_id,
            nickname=request.nickname,
            species_selection_method=request.species_selection_method.value,
            started_on=request.started_on,
            place_name=request.place_name,
            pot_type=request.pot_type.value,
            placement=request.placement.value,
            personality_type=request.personality_type.value,
            color_id=request.color_id,
            hair_id=request.hair_id,
            accessory_id=request.accessory_id,
            created_at=now,
            updated_at=now,
        )
        watering_schedule = CareSchedule(
            id=uuid4(),
            plant_id=plant.id,
            type=CareScheduleType.WATERING.value,
            interval_days=guide.default_watering_interval_days,
            next_due_date=request.last_watered_on
            + timedelta(days=guide.default_watering_interval_days),
            recommended_water_min_ml=guide.recommended_water_min_ml,
            recommended_water_max_ml=guide.recommended_water_max_ml,
            recommendation_source=(
                WaterRecommendationSource.SPECIES_GUIDE.value
                if guide.recommended_water_min_ml is not None
                and guide.recommended_water_max_ml is not None
                else None
            ),
            enabled=True,
            created_at=now,
            updated_at=now,
        )
        watering_event = completed_care_event(
            plant_id=plant.id,
            schedule_id=watering_schedule.id,
            care_type=CareEventType.WATERING,
            performed_on=request.last_watered_on,
            recorded_at=now,
        )
        conversation = AIConversation(
            id=uuid4(),
            plant_id=plant.id,
            title="새 채팅",
            created_at=now,
            updated_at=now,
        )

        care_schedules: list[CareSchedule] = [watering_schedule]
        care_events: list[CareEvent] = [watering_event]
        repotting_base_date: date | None = None
        if request.repotting_history.status == RepottingHistoryStatus.KNOWN:
            assert request.repotting_history.date is not None
            repotting_base_date = request.repotting_history.date
        elif request.repotting_history.status == RepottingHistoryStatus.NEVER:
            repotting_base_date = request.started_on

        repotting_schedule: CareSchedule | None = None
        if repotting_base_date is not None and guide.default_repotting_interval_days is not None:
            repotting_schedule = CareSchedule(
                id=uuid4(),
                plant_id=plant.id,
                type=CareScheduleType.REPOTTING.value,
                interval_days=guide.default_repotting_interval_days,
                next_due_date=next_recurring_due_date(
                    repotting_base_date,
                    guide.default_repotting_interval_days,
                    today,
                ),
                recommended_water_min_ml=None,
                recommended_water_max_ml=None,
                recommendation_source=None,
                enabled=True,
                created_at=now,
                updated_at=now,
            )
            care_schedules.append(repotting_schedule)

        if request.repotting_history.status == RepottingHistoryStatus.KNOWN:
            assert request.repotting_history.date is not None
            care_events.append(
                completed_care_event(
                    plant_id=plant.id,
                    schedule_id=(
                        repotting_schedule.id if repotting_schedule is not None else None
                    ),
                    care_type=CareEventType.REPOTTING,
                    performed_on=request.repotting_history.date,
                    recorded_at=now,
                )
            )

        # These models use explicit UUID foreign keys without ORM relationships.
        # Flush parents first so PostgreSQL never receives child INSERTs before
        # their referenced plant and schedule rows exist.
        await self._repository.add_registration(plant)
        await self._repository.add_registration(*care_schedules, conversation)
        await self._repository.add_registration(*care_events)
        profile.selected_plant_id = plant.id
        await self._repository.flush()
        return PlantCreateResponse(id=plant.id, created_at=now)

    async def _validate_identification(
        self,
        user_id: UUID,
        request: PlantCreateRequest,
    ) -> SpeciesIdentification | None:
        if request.species_selection_method == SpeciesSelectionMethod.SEARCH:
            return None

        assert request.species_identification_id is not None
        assert request.primary_media_file_id is not None
        identification = await self._repository.get_identification_for_update(
            request.species_identification_id,
            user_id,
        )
        if identification is None:
            raise AppError(
                code="SPECIES_IDENTIFICATION_NOT_FOUND",
                message="식물 인식 결과를 찾을 수 없습니다.",
                status_code=404,
            )
        if identification.status != SpeciesIdentificationStatus.COMPLETED:
            raise AppError(
                code="SPECIES_IDENTIFICATION_NOT_COMPLETED",
                message="완료된 식물 인식 결과만 등록에 사용할 수 있습니다.",
                status_code=409,
            )
        if await self._repository.identification_is_used(identification.id):
            raise AppError(
                code="SPECIES_IDENTIFICATION_ALREADY_USED",
                message="이미 식물 등록에 사용한 인식 결과입니다.",
                status_code=409,
            )
        if not candidate_contains_reference(
            identification.candidates or [], request.species_reference_id
        ):
            raise AppError(
                code="SPECIES_CANDIDATE_MISMATCH",
                message="선택한 식물이 사진 인식 후보에 포함되어 있지 않습니다.",
                status_code=409,
            )
        if identification.media_file_id != request.primary_media_file_id:
            raise AppError(
                code="SPECIES_IDENTIFICATION_MEDIA_MISMATCH",
                message="식물 인식에 사용한 사진을 대표 사진으로 지정해야 합니다.",
                status_code=409,
            )

        media_file = await self._repository.get_media_owned(request.primary_media_file_id, user_id)
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
        return identification

    @staticmethod
    def _validate_dates(request: PlantCreateRequest, today: date) -> None:
        dates = [request.started_on, request.last_watered_on]
        if request.repotting_history.date is not None:
            dates.append(request.repotting_history.date)
        if any(value > today for value in dates):
            raise AppError(
                code="FUTURE_DATE_NOT_ALLOWED",
                message="미래 날짜는 입력할 수 없습니다.",
                status_code=400,
            )


def completed_care_event(
    *,
    plant_id: UUID,
    schedule_id: UUID | None,
    care_type: CareEventType,
    performed_on: date,
    recorded_at: datetime,
) -> CareEvent:
    return CareEvent(
        id=uuid4(),
        plant_id=plant_id,
        schedule_id=schedule_id,
        type=care_type.value,
        status=CareEventStatus.COMPLETED.value,
        source=CareEventSource.USER_CREATED.value,
        due_date=performed_on,
        performed_on=performed_on,
        recorded_at=recorded_at,
        created_at=recorded_at,
        updated_at=recorded_at,
    )


def registration_request_hash(request: PlantCreateRequest) -> str:
    payload = request.model_dump(mode="json", exclude={"client_registration_id"})
    canonical_json = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical_json.encode("utf-8")).hexdigest()


def candidate_contains_reference(candidates: list, species_reference_id: str) -> bool:
    return any(
        isinstance(candidate, dict) and candidate.get("reference_id") == species_reference_id
        for candidate in candidates
    )


def next_recurring_due_date(base_date: date, interval_days: int, today: date) -> date:
    next_due_date = base_date + timedelta(days=interval_days)
    if next_due_date >= today:
        return next_due_date

    elapsed_days = (today - next_due_date).days
    skipped_intervals = (elapsed_days + interval_days - 1) // interval_days
    return next_due_date + timedelta(days=skipped_intervals * interval_days)


def today_in_timezone(timezone_name: str) -> date:
    try:
        timezone = ZoneInfo(timezone_name)
    except ZoneInfoNotFoundError:
        timezone = ZoneInfo("Asia/Seoul")
    return datetime.now(timezone).date()
