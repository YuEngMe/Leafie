import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.care import CareEvent, CareSchedule
from app.models.enums import (
    CareEventSource,
    CareEventStatus,
    CareEventType,
    CareScheduleType,
)
from app.models.plant import Plant, SpeciesCareGuide
from app.models.user import UserProfile
from app.schemas.care import (
    CareEventCompleteRequest,
    CareEventCompleteResponse,
    CareEventCreateRequest,
    CareEventResponse,
    NextCareEventResponse,
)
from app.services.plant import next_recurring_due_date, today_in_timezone


@dataclass(frozen=True, slots=True)
class OwnedPlantContext:
    plant_id: UUID
    timezone: str
    default_repotting_interval_days: int | None


@dataclass(frozen=True, slots=True)
class CareEventContext:
    event: CareEvent
    timezone: str


@dataclass(frozen=True, slots=True)
class MutationResult:
    response: CareEventResponse
    created: bool


class CareRepository(Protocol):
    async def get_owned_plant(
        self, plant_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> OwnedPlantContext | None: ...

    async def get_event_by_client_id(
        self, plant_id: UUID, client_event_id: UUID
    ) -> CareEvent | None: ...

    async def get_scheduled_repotting_for_update(
        self, plant_id: UUID
    ) -> CareEvent | None: ...

    async def get_event_for_update(
        self, event_id: UUID, user_id: UUID
    ) -> CareEventContext | None: ...

    async def get_schedule_for_update(self, schedule_id: UUID) -> CareSchedule | None: ...

    async def get_repotting_schedule_for_update(
        self, plant_id: UUID
    ) -> CareSchedule | None: ...

    async def get_scheduled_event(self, schedule_id: UUID) -> CareEvent | None: ...

    async def add(self, instance: object) -> None: ...

    async def flush(self) -> None: ...


class SQLAlchemyCareRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_owned_plant(
        self, plant_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> OwnedPlantContext | None:
        statement = (
            select(
                Plant.id,
                UserProfile.timezone,
                SpeciesCareGuide.default_repotting_interval_days,
            )
            .join(UserProfile, UserProfile.user_id == Plant.user_id)
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
        if lock:
            statement = statement.with_for_update(of=Plant)
        row = (await self._session.execute(statement)).one_or_none()
        if row is None:
            return None
        return OwnedPlantContext(
            plant_id=row.id,
            timezone=row.timezone,
            default_repotting_interval_days=row.default_repotting_interval_days,
        )

    async def get_event_by_client_id(
        self, plant_id: UUID, client_event_id: UUID
    ) -> CareEvent | None:
        return await self._session.scalar(
            select(CareEvent).where(
                CareEvent.plant_id == plant_id,
                CareEvent.client_event_id == client_event_id,
            )
        )

    async def get_event_for_update(
        self, event_id: UUID, user_id: UUID
    ) -> CareEventContext | None:
        row = (
            await self._session.execute(
                select(CareEvent, UserProfile.timezone)
                .join(Plant, Plant.id == CareEvent.plant_id)
                .join(UserProfile, UserProfile.user_id == Plant.user_id)
                .where(
                    CareEvent.id == event_id,
                    Plant.user_id == user_id,
                    Plant.deleted_at.is_(None),
                )
                .with_for_update(of=CareEvent)
            )
        ).one_or_none()
        if row is None:
            return None
        return CareEventContext(event=row[0], timezone=row.timezone)

    async def get_scheduled_repotting_for_update(
        self, plant_id: UUID
    ) -> CareEvent | None:
        return await self._session.scalar(
            select(CareEvent)
            .where(
                CareEvent.plant_id == plant_id,
                CareEvent.type == CareEventType.REPOTTING.value,
                CareEvent.status == CareEventStatus.SCHEDULED.value,
            )
            .order_by(CareEvent.created_at, CareEvent.id)
            .limit(1)
            .with_for_update()
        )

    async def get_schedule_for_update(self, schedule_id: UUID) -> CareSchedule | None:
        return await self._session.scalar(
            select(CareSchedule).where(CareSchedule.id == schedule_id).with_for_update()
        )

    async def get_repotting_schedule_for_update(
        self, plant_id: UUID
    ) -> CareSchedule | None:
        return await self._session.scalar(
            select(CareSchedule)
            .where(
                CareSchedule.plant_id == plant_id,
                CareSchedule.type == CareScheduleType.REPOTTING.value,
            )
            .with_for_update()
        )

    async def get_scheduled_event(self, schedule_id: UUID) -> CareEvent | None:
        return await self._session.scalar(
            select(CareEvent).where(
                CareEvent.schedule_id == schedule_id,
                CareEvent.status == CareEventStatus.SCHEDULED.value,
            )
        )

    async def add(self, instance: object) -> None:
        self._session.add(instance)
        await self._session.flush()

    async def flush(self) -> None:
        await self._session.flush()


class CareService:
    def __init__(self, repository: CareRepository) -> None:
        self._repository = repository

    async def create_event(
        self, user_id: UUID, plant_id: UUID, request: CareEventCreateRequest
    ) -> MutationResult:
        context = await self._require_plant(user_id, plant_id, lock=True)
        request_hash = care_event_request_hash(request)
        existing = await self._repository.get_event_by_client_id(
            plant_id, request.client_event_id
        )
        if existing is not None:
            if existing.creation_request_hash != request_hash:
                raise AppError(
                    code="CLIENT_EVENT_ID_REUSED",
                    message="이미 다른 일정 생성에 사용한 client_event_id입니다.",
                    status_code=409,
                )
            return MutationResult(response=event_response(existing), created=False)

        if request.due_date < today_in_timezone(context.timezone):
            raise AppError(
                code="PAST_DUE_DATE_NOT_ALLOWED",
                message="일회성 일정은 오늘 또는 미래 날짜로 만들어 주세요.",
                status_code=400,
            )

        if request.care_type == CareEventType.REPOTTING:
            return await self._upsert_repotting(context, request, request_hash)

        now = datetime.now(UTC)
        event = CareEvent(
            id=uuid4(),
            plant_id=plant_id,
            client_event_id=request.client_event_id,
            creation_request_hash=request_hash,
            type=request.care_type.value,
            status=CareEventStatus.SCHEDULED.value,
            source=CareEventSource.USER_CREATED.value,
            due_date=request.due_date,
            created_at=now,
            updated_at=now,
        )
        await self._repository.add(event)
        return MutationResult(response=event_response(event), created=True)

    async def _upsert_repotting(
        self,
        context: OwnedPlantContext,
        request: CareEventCreateRequest,
        request_hash: str,
    ) -> MutationResult:
        now = datetime.now(UTC)
        schedule = await self._repository.get_repotting_schedule_for_update(context.plant_id)
        event = await self._repository.get_scheduled_repotting_for_update(context.plant_id)

        if schedule is None and context.default_repotting_interval_days is not None:
            schedule = CareSchedule(
                id=uuid4(),
                plant_id=context.plant_id,
                type=CareScheduleType.REPOTTING.value,
                interval_days=context.default_repotting_interval_days,
                next_due_date=request.due_date,
                enabled=True,
                created_at=now,
                updated_at=now,
            )
            await self._repository.add(schedule)
        elif schedule is not None:
            schedule.next_due_date = request.due_date
            schedule.enabled = True
            schedule.updated_at = now

        if event is None:
            event = CareEvent(
                id=uuid4(),
                plant_id=context.plant_id,
                schedule_id=schedule.id if schedule is not None else None,
                client_event_id=request.client_event_id,
                creation_request_hash=request_hash,
                type=CareEventType.REPOTTING.value,
                status=CareEventStatus.SCHEDULED.value,
                source=CareEventSource.USER_CREATED.value,
                due_date=request.due_date,
                created_at=now,
                updated_at=now,
            )
            await self._repository.add(event)
            return MutationResult(response=event_response(event), created=True)

        event.schedule_id = schedule.id if schedule is not None else event.schedule_id
        event.client_event_id = request.client_event_id
        event.creation_request_hash = request_hash
        event.due_date = request.due_date
        event.updated_at = now
        await self._repository.flush()
        return MutationResult(response=event_response(event), created=False)

    async def complete_event(
        self, user_id: UUID, event_id: UUID, request: CareEventCompleteRequest
    ) -> CareEventCompleteResponse:
        context = await self._repository.get_event_for_update(event_id, user_id)
        if context is None:
            raise AppError(
                code="CARE_EVENT_NOT_FOUND",
                message="관리 일정을 찾을 수 없습니다.",
                status_code=404,
            )
        event = context.event
        if event.status == CareEventStatus.CANCELLED.value:
            raise AppError(
                code="CARE_EVENT_CANCELLED",
                message="취소한 일정은 완료할 수 없습니다.",
                status_code=409,
            )
        if event.status == CareEventStatus.COMPLETED.value:
            return completion_response(event, await self._next_event(event.schedule_id))

        today = today_in_timezone(context.timezone)
        performed_on = request.performed_on or today
        if performed_on > today:
            raise AppError(
                code="FUTURE_DATE_NOT_ALLOWED",
                message="미래 날짜로 완료할 수 없습니다.",
                status_code=400,
            )

        now = datetime.now(UTC)
        event.status = CareEventStatus.COMPLETED.value
        event.performed_on = performed_on
        event.recorded_at = now
        event.updated_at = now
        await self._repository.flush()

        next_event: CareEvent | None = None
        if event.schedule_id is not None:
            schedule = await self._repository.get_schedule_for_update(event.schedule_id)
            if schedule is not None and schedule.enabled:
                next_due_date = next_recurring_due_date(
                    performed_on,
                    schedule.interval_days,
                    today,
                )
                schedule.next_due_date = next_due_date
                schedule.updated_at = now
                next_event = CareEvent(
                    id=uuid4(),
                    plant_id=event.plant_id,
                    schedule_id=schedule.id,
                    type=event.type,
                    status=CareEventStatus.SCHEDULED.value,
                    source=CareEventSource.AUTO_SCHEDULE.value,
                    due_date=next_due_date,
                    created_at=now,
                    updated_at=now,
                )
                await self._repository.add(next_event)

        return completion_response(event, next_event)

    async def _require_plant(
        self, user_id: UUID, plant_id: UUID, *, lock: bool = False
    ) -> OwnedPlantContext:
        context = await self._repository.get_owned_plant(plant_id, user_id, lock=lock)
        if context is None:
            raise AppError(
                code="PLANT_NOT_FOUND",
                message="식물을 찾을 수 없습니다.",
                status_code=404,
            )
        return context

    async def _next_event(self, schedule_id: UUID | None) -> CareEvent | None:
        if schedule_id is None:
            return None
        return await self._repository.get_scheduled_event(schedule_id)

def care_event_request_hash(request: CareEventCreateRequest) -> str:
    payload = request.model_dump(mode="json", exclude={"client_event_id"})
    canonical_json = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical_json.encode("utf-8")).hexdigest()


def event_response(event: CareEvent) -> CareEventResponse:
    return CareEventResponse(
        id=event.id,
        plant_id=event.plant_id,
        schedule_id=event.schedule_id,
        client_event_id=event.client_event_id,
        care_type=event.type,
        status=event.status,
        source=event.source,
        due_date=event.due_date,
        performed_on=event.performed_on,
        recorded_at=event.recorded_at,
        created_at=event.created_at,
        updated_at=event.updated_at,
    )


def completion_response(
    event: CareEvent, next_event: CareEvent | None
) -> CareEventCompleteResponse:
    return CareEventCompleteResponse(
        **event_response(event).model_dump(),
        next_event=(
            NextCareEventResponse(id=next_event.id, due_date=next_event.due_date)
            if next_event is not None
            else None
        ),
    )
