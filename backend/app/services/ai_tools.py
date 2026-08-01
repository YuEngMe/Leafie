import json
from datetime import UTC, date, datetime, timedelta
from time import monotonic
from typing import Any, Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field, ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.integrations.openai_chat import ChatToolCall
from app.models.care import CareEvent
from app.models.chat import AIAction, AIToolCall
from app.models.diagnosis import Diagnosis
from app.models.enums import (
    AIActionStatus,
    CareEventSource,
    CareEventStatus,
    DiagnosisStatus,
    ToolCallStatus,
)
from app.models.plant import Plant, PlantDiary, SpeciesCareGuide
from app.schemas.chat import AIActionResponse


class _NoArguments(BaseModel):
    model_config = ConfigDict(extra="forbid")


class _WindowArguments(BaseModel):
    model_config = ConfigDict(extra="forbid")

    days: int = Field(ge=1, le=90)


class _LimitArguments(BaseModel):
    model_config = ConfigDict(extra="forbid")

    limit: int = Field(ge=1, le=10)


class _CareProposalArguments(BaseModel):
    model_config = ConfigDict(extra="forbid")

    care_type: Literal["FERTILIZING", "PRUNING"]
    due_date: date
    title: str = Field(min_length=1, max_length=200)
    reason: str = Field(min_length=1, max_length=500)


TOOL_DEFINITIONS: list[dict[str, Any]] = [
    {
        "type": "function",
        "name": "get_plant_basic_info",
        "description": "현재 상담 중인 식물의 이름, 분류, 학명 등 기본 정보를 조회합니다.",
        "parameters": _NoArguments.model_json_schema(),
        "strict": True,
    },
    {
        "type": "function",
        "name": "get_species_care_guide",
        "description": "현재 식물 종의 물주기, 분갈이, 빛 등 내부 관리 가이드를 조회합니다.",
        "parameters": _NoArguments.model_json_schema(),
        "strict": True,
    },
    {
        "type": "function",
        "name": "get_plant_environment",
        "description": "현재 식물의 화분, 장소, 위치와 함께한 시작일을 조회합니다.",
        "parameters": _NoArguments.model_json_schema(),
        "strict": True,
    },
    {
        "type": "function",
        "name": "get_upcoming_care_schedule",
        "description": "지연된 일정과 오늘부터 지정 기간 안의 예정 관리 일정을 조회합니다.",
        "parameters": _WindowArguments.model_json_schema(),
        "strict": True,
    },
    {
        "type": "function",
        "name": "get_recent_care_history",
        "description": "최근 완료한 물주기, 분갈이 등 관리 이력을 조회합니다.",
        "parameters": _LimitArguments.model_json_schema(),
        "strict": True,
    },
    {
        "type": "function",
        "name": "get_recent_diary_conditions",
        "description": "최근 다이어리 날짜와 컨디션 점수를 조회합니다.",
        "parameters": _LimitArguments.model_json_schema(),
        "strict": True,
    },
    {
        "type": "function",
        "name": "get_recent_diagnosis",
        "description": "가장 최근 완료된 사진 진단 결과를 조회합니다.",
        "parameters": _NoArguments.model_json_schema(),
        "strict": True,
    },
    {
        "type": "function",
        "name": "propose_one_time_care",
        "description": (
            "비료 주기 또는 가지치기 일정을 사용자에게 제안합니다. "
            "승인 대기 제안만 만들며 일정은 즉시 생성하지 않습니다."
        ),
        "parameters": _CareProposalArguments.model_json_schema(),
        "strict": True,
    },
]


class SQLAlchemyAIToolRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def plant_and_guide(
        self, user_id: UUID, plant_id: UUID
    ) -> tuple[Plant, SpeciesCareGuide] | None:
        return (
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

    async def upcoming_events(self, plant_id: UUID, through: date) -> list[CareEvent]:
        return list(
            (
                await self._session.scalars(
                    select(CareEvent)
                    .where(
                        CareEvent.plant_id == plant_id,
                        CareEvent.status == CareEventStatus.SCHEDULED.value,
                        CareEvent.due_date <= through,
                    )
                    .order_by(CareEvent.due_date, CareEvent.created_at)
                    .limit(30)
                )
            ).all()
        )

    async def recent_care_events(self, plant_id: UUID, limit: int) -> list[CareEvent]:
        return list(
            (
                await self._session.scalars(
                    select(CareEvent)
                    .where(
                        CareEvent.plant_id == plant_id,
                        CareEvent.status == CareEventStatus.COMPLETED.value,
                    )
                    .order_by(CareEvent.performed_on.desc(), CareEvent.recorded_at.desc())
                    .limit(limit)
                )
            ).all()
        )

    async def recent_diaries(self, plant_id: UUID, limit: int) -> list[PlantDiary]:
        return list(
            (
                await self._session.scalars(
                    select(PlantDiary)
                    .where(PlantDiary.plant_id == plant_id)
                    .order_by(PlantDiary.diary_date.desc())
                    .limit(limit)
                )
            ).all()
        )

    async def recent_diagnosis(self, plant_id: UUID) -> Diagnosis | None:
        return await self._session.scalar(
            select(Diagnosis)
            .where(
                Diagnosis.plant_id == plant_id,
                Diagnosis.status == DiagnosisStatus.COMPLETED.value,
            )
            .order_by(Diagnosis.completed_at.desc(), Diagnosis.created_at.desc())
            .limit(1)
        )

    async def add(self, instance: object) -> None:
        self._session.add(instance)
        await self._session.flush()

    async def action_owned(
        self, action_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> AIAction | None:
        statement = (
            select(AIAction)
            .join(Plant, Plant.id == AIAction.plant_id)
            .where(
                AIAction.id == action_id,
                AIAction.user_id == user_id,
                Plant.user_id == user_id,
                Plant.deleted_at.is_(None),
            )
        )
        if lock:
            statement = statement.with_for_update(of=AIAction)
        return await self._session.scalar(statement)


class AIToolService:
    def __init__(self, repository: SQLAlchemyAIToolRepository) -> None:
        self._repository = repository

    async def execute(
        self,
        *,
        call: ChatToolCall,
        message_id: UUID,
        user_id: UUID,
        plant_id: UUID,
    ) -> str:
        started = monotonic()
        invalid_json = False
        try:
            raw_arguments = json.loads(call.arguments)
            if not isinstance(raw_arguments, dict):
                raise ValueError
        except (json.JSONDecodeError, ValueError):
            raw_arguments = {}
            invalid_json = True

        audit = AIToolCall(
            id=uuid4(),
            message_id=message_id,
            provider_call_id=call.call_id,
            tool_name=call.name,
            arguments=raw_arguments,
            status=ToolCallStatus.PENDING.value,
        )
        await self._repository.add(audit)

        try:
            if invalid_json:
                raise ValueError("invalid json")
            result = await self._dispatch(call.name, raw_arguments, user_id, plant_id, message_id)
        except (ValidationError, ValueError):
            audit.status = ToolCallStatus.FAILED.value
            audit.error_code = "INVALID_TOOL_ARGUMENTS"
            audit.result_summary = {"ok": False, "error": "도구 입력값이 올바르지 않습니다."}
            result = audit.result_summary
        except AppError as exc:
            audit.status = ToolCallStatus.FAILED.value
            audit.error_code = exc.code
            audit.result_summary = {"ok": False, "error": exc.message}
            result = audit.result_summary
        except Exception:
            audit.status = ToolCallStatus.FAILED.value
            audit.error_code = "AI_TOOL_EXECUTION_FAILED"
            audit.completed_at = datetime.now(UTC)
            audit.latency_ms = int((monotonic() - started) * 1000)
            raise
        else:
            audit.status = ToolCallStatus.COMPLETED.value
            result = json.loads(json.dumps(result, ensure_ascii=False, default=str))
            audit.result_summary = result
        audit.latency_ms = int((monotonic() - started) * 1000)
        audit.completed_at = datetime.now(UTC)
        return json.dumps(result, ensure_ascii=False, default=str)

    async def _dispatch(
        self,
        name: str,
        arguments: dict[str, Any],
        user_id: UUID,
        plant_id: UUID,
        message_id: UUID,
    ) -> dict[str, Any]:
        plant, guide = await self._require_plant(user_id, plant_id)

        if name == "get_plant_basic_info":
            _NoArguments.model_validate(arguments)
            return {
                "nickname": plant.nickname,
                "species_name": guide.display_name,
                "scientific_name": guide.scientific_name,
                "family_name": guide.family_name,
                "category": guide.category,
            }
        if name == "get_species_care_guide":
            _NoArguments.model_validate(arguments)
            return {
                "recommended_water_min_ml": guide.recommended_water_min_ml,
                "recommended_water_max_ml": guide.recommended_water_max_ml,
                "watering_interval_days": guide.default_watering_interval_days,
                "repotting_interval_days": guide.default_repotting_interval_days,
                "care_profile": guide.care_profile,
                "reviewed_at": guide.reviewed_at,
            }
        if name == "get_plant_environment":
            _NoArguments.model_validate(arguments)
            return {
                "place_name": plant.place_name,
                "pot_type": plant.pot_type,
                "placement": plant.placement,
                "started_on": plant.started_on,
            }
        if name == "get_upcoming_care_schedule":
            parsed = _WindowArguments.model_validate(arguments)
            today = date.today()
            events = await self._repository.upcoming_events(
                plant_id, today + timedelta(days=parsed.days)
            )
            return {
                "today": today,
                "items": [
                    {
                        "type": event.type,
                        "title": event.title,
                        "due_date": event.due_date,
                        "overdue": event.due_date < today,
                    }
                    for event in events
                ],
            }
        if name == "get_recent_care_history":
            parsed = _LimitArguments.model_validate(arguments)
            events = await self._repository.recent_care_events(plant_id, parsed.limit)
            return {
                "items": [
                    {
                        "type": event.type,
                        "title": event.title,
                        "performed_on": event.performed_on,
                    }
                    for event in events
                ]
            }
        if name == "get_recent_diary_conditions":
            parsed = _LimitArguments.model_validate(arguments)
            diaries = await self._repository.recent_diaries(plant_id, parsed.limit)
            return {
                "items": [
                    {"diary_date": diary.diary_date, "condition_score": diary.condition_score}
                    for diary in diaries
                ]
            }
        if name == "get_recent_diagnosis":
            _NoArguments.model_validate(arguments)
            diagnosis = await self._repository.recent_diagnosis(plant_id)
            if diagnosis is None:
                return {"diagnosis": None}
            return {
                "diagnosis": {
                    "condition": diagnosis.overall_condition,
                    "label": diagnosis.condition_label,
                    "observations": diagnosis.observations,
                    "possible_causes": diagnosis.possible_causes,
                    "recommended_care": diagnosis.recommended_care,
                    "completed_at": diagnosis.completed_at,
                }
            }
        if name == "propose_one_time_care":
            parsed = _CareProposalArguments.model_validate(arguments)
            if parsed.due_date < date.today():
                raise ValueError("past due date")
            action = AIAction(
                id=uuid4(),
                user_id=user_id,
                message_id=message_id,
                plant_id=plant_id,
                action_type="CREATE_ONE_TIME_CARE_EVENT",
                payload=parsed.model_dump(mode="json"),
                status=AIActionStatus.PENDING_CONFIRMATION.value,
                expires_at=datetime.now(UTC) + timedelta(hours=24),
            )
            await self._repository.add(action)
            return {
                "action_id": str(action.id),
                "status": action.status,
                "proposal": action.payload,
                "expires_at": action.expires_at,
                "requires_user_confirmation": True,
            }
        raise AppError(
            code="UNKNOWN_AI_TOOL",
            message="지원하지 않는 AI 도구입니다.",
            status_code=422,
        )

    async def _require_plant(
        self, user_id: UUID, plant_id: UUID
    ) -> tuple[Plant, SpeciesCareGuide]:
        row = await self._repository.plant_and_guide(user_id, plant_id)
        if row is None:
            raise AppError(
                code="PLANT_NOT_FOUND",
                message="식물을 찾을 수 없습니다.",
                status_code=404,
            )
        return row


class AIActionService:
    def __init__(self, repository: SQLAlchemyAIToolRepository) -> None:
        self._repository = repository

    async def confirm(self, user_id: UUID, action_id: UUID) -> AIActionResponse:
        action = await self._require_pending(user_id, action_id)
        parsed = _CareProposalArguments.model_validate(action.payload)
        event = CareEvent(
            id=uuid4(),
            plant_id=action.plant_id,
            type=parsed.care_type,
            title=parsed.title,
            status=CareEventStatus.SCHEDULED.value,
            source=CareEventSource.AI_RECOMMENDED.value,
            due_date=parsed.due_date,
        )
        await self._repository.add(event)
        now = datetime.now(UTC)
        action.status = AIActionStatus.COMPLETED.value
        action.confirmed_at = now
        action.executed_at = now
        return action_to_response(action)

    async def cancel(self, user_id: UUID, action_id: UUID) -> AIActionResponse:
        action = await self._require_pending(user_id, action_id)
        action.status = AIActionStatus.CANCELLED.value
        return action_to_response(action)

    async def _require_pending(self, user_id: UUID, action_id: UUID) -> AIAction:
        action = await self._repository.action_owned(action_id, user_id, lock=True)
        if action is None:
            raise AppError(
                code="AI_ACTION_NOT_FOUND",
                message="AI 제안을 찾을 수 없습니다.",
                status_code=404,
            )
        if action.status != AIActionStatus.PENDING_CONFIRMATION.value:
            raise AppError(
                code="AI_ACTION_NOT_PENDING",
                message="이미 처리된 AI 제안입니다.",
                status_code=409,
            )
        if action.expires_at is not None and action.expires_at <= datetime.now(UTC):
            raise AppError(
                code="AI_ACTION_EXPIRED",
                message="AI 제안이 만료되었습니다.",
                status_code=409,
            )
        if action.action_type != "CREATE_ONE_TIME_CARE_EVENT":
            raise AppError(
                code="AI_ACTION_TYPE_NOT_ALLOWED",
                message="허용되지 않은 AI 제안입니다.",
                status_code=409,
            )
        return action


def action_to_response(action: AIAction) -> AIActionResponse:
    return AIActionResponse(
        id=action.id,
        plant_id=action.plant_id,
        action_type=action.action_type,
        payload=action.payload,
        status=AIActionStatus(action.status),
        expires_at=action.expires_at,
        confirmed_at=action.confirmed_at,
        executed_at=action.executed_at,
        created_at=action.created_at,
    )
