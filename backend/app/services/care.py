import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, date, datetime
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.care import CareEvent, CareSchedule
from app.models.enums import CareEventSource, CareEventStatus
from app.models.plant import Plant, PlantDailyMemo
from app.models.user import UserProfile
from app.schemas.care import (
    CareEventCompleteRequest,
    CareEventCompleteResponse,
    CareEventCreateRequest,
    CareEventResponse,
    DailyMemoResponse,
    DailyMemoUpsertRequest,
    NextCareEventResponse,
)
from app.services.plant import next_recurring_due_date, today_in_timezone


@dataclass(frozen=True, slots=True)
class OwnedPlantContext:
    plant_id: UUID
    timezone: str


@dataclass(frozen=True, slots=True)
class CareEventContext:
    event: CareEvent
    timezone: str


@dataclass(frozen=True, slots=True)
class MutationResult:
    response: CareEventResponse | DailyMemoResponse
    created: bool


class CareRepository(Protocol):
    async def get_owned_plant(
        self, plant_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> OwnedPlantContext | None: ...

    async def get_event_by_client_id(
        self, plant_id: UUID, client_event_id: UUID
    ) -> CareEvent | None: ...

    async def get_event_for_update(
        self, event_id: UUID, user_id: UUID
    ) -> CareEventContext | None: ...

    async def get_schedule_for_update(self, schedule_id: UUID) -> CareSchedule | None: ...

    async def get_scheduled_event(self, schedule_id: UUID) -> CareEvent | None: ...

    async def get_memo(
        self, plant_id: UUID, memo_date: date, *, lock: bool = False
    ) -> PlantDailyMemo | None: ...

    async def add(self, instance: object) -> None: ...

    async def delete(self, instance: object) -> None: ...

    async def flush(self) -> None: ...


class SQLAlchemyCareRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_owned_plant(
        self, plant_id: UUID, user_id: UUID, *, lock: bool = False
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

    async def get_schedule_for_update(self, schedule_id: UUID) -> CareSchedule | None:
        return await self._session.scalar(
            select(CareSchedule).where(CareSchedule.id == schedule_id).with_for_update()
        )

    async def get_scheduled_event(self, schedule_id: UUID) -> CareEvent | None:
        return await self._session.scalar(
            select(CareEvent).where(
                CareEvent.schedule_id == schedule_id,
                CareEvent.status == CareEventStatus.SCHEDULED.value,
            )
        )

    async def get_memo(
        self, plant_id: UUID, memo_date: date, *, lock: bool = False
    ) -> PlantDailyMemo | None:
        statement = select(PlantDailyMemo).where(
            PlantDailyMemo.plant_id == plant_id,
            PlantDailyMemo.memo_date == memo_date,
        )
        if lock:
            statement = statement.with_for_update()
        return await self._session.scalar(statement)

    async def add(self, instance: object) -> None:
        self._session.add(instance)
        await self._session.flush()

    async def delete(self, instance: object) -> None:
        await self._session.delete(instance)
        await self._session.flush()

    async def flush(self) -> None:
        await self._session.flush()


class CareService:
    def __init__(self, repository: CareRepository) -> None:
        self._repository = repository

    async def create_one_time_event(
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

        now = datetime.now(UTC)
        event = CareEvent(
            id=uuid4(),
            plant_id=plant_id,
            client_event_id=request.client_event_id,
            creation_request_hash=request_hash,
            type=request.type.value,
            title=request.title,
            status=CareEventStatus.SCHEDULED.value,
            source=CareEventSource.USER_CREATED.value,
            due_date=request.due_date,
            created_at=now,
            updated_at=now,
        )
        await self._repository.add(event)
        return MutationResult(response=event_response(event), created=True)

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

    async def upsert_daily_memo(
        self,
        user_id: UUID,
        plant_id: UUID,
        memo_date: date,
        request: DailyMemoUpsertRequest,
    ) -> MutationResult:
        context = await self._require_plant(user_id, plant_id, lock=True)
        self._require_today(memo_date, context.timezone)
        memo = await self._repository.get_memo(plant_id, memo_date, lock=True)
        now = datetime.now(UTC)
        created = memo is None
        if memo is None:
            memo = PlantDailyMemo(
                id=uuid4(),
                plant_id=plant_id,
                memo_date=memo_date,
                content=request.content,
                created_at=now,
                updated_at=now,
            )
            await self._repository.add(memo)
        elif memo.content != request.content:
            memo.content = request.content
            memo.updated_at = now
            await self._repository.flush()
        return MutationResult(response=memo_response(memo), created=created)

    async def delete_daily_memo(
        self, user_id: UUID, plant_id: UUID, memo_date: date
    ) -> None:
        context = await self._require_plant(user_id, plant_id, lock=True)
        self._require_today(memo_date, context.timezone)
        memo = await self._repository.get_memo(plant_id, memo_date, lock=True)
        if memo is not None:
            await self._repository.delete(memo)

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

    @staticmethod
    def _require_today(value: date, timezone: str) -> None:
        if value != today_in_timezone(timezone):
            raise AppError(
                code="DAILY_MEMO_DATE_NOT_TODAY",
                message="홈 메모는 오늘 날짜에만 작성하거나 삭제할 수 있습니다.",
                status_code=400,
            )


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
        type=event.type,
        title=event.title,
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


def memo_response(memo: PlantDailyMemo) -> DailyMemoResponse:
    return DailyMemoResponse(
        id=memo.id,
        plant_id=memo.plant_id,
        date=memo.memo_date,
        content=memo.content,
        created_at=memo.created_at,
        updated_at=memo.updated_at,
    )
