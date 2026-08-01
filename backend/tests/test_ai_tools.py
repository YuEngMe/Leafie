import json
from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.core.errors import AppError
from app.integrations.openai_chat import ChatToolCall
from app.models.care import CareEvent
from app.models.chat import AIAction, AIToolCall
from app.models.enums import AIActionStatus, CareEventSource, CareEventStatus, ToolCallStatus
from app.services.ai_tools import (
    TOOL_DEFINITIONS,
    AIActionService,
    AIToolService,
)


class FakeToolRepository:
    def __init__(self, *, action: AIAction | None = None, owns_plant: bool = True) -> None:
        self.action = action
        self.owns_plant = owns_plant
        self.added: list[object] = []

    async def plant_and_guide(self, _user_id, _plant_id):
        if not self.owns_plant:
            return None
        return (
            SimpleNamespace(
                nickname="새싹이",
                place_name="집",
                pot_type="PLASTIC",
                placement="WINDOW",
                started_on=date(2026, 7, 1),
            ),
            SimpleNamespace(
                display_name="바질",
                scientific_name="Ocimum basilicum",
                family_name="꿀풀과",
                category="HERB",
                recommended_water_min_ml=100,
                recommended_water_max_ml=200,
                default_watering_interval_days=3,
                default_repotting_interval_days=365,
                care_profile={"light": "bright"},
                reviewed_at=date(2026, 7, 1),
            ),
        )

    async def upcoming_events(self, _plant_id, _through):
        return []

    async def recent_care_events(self, _plant_id, _limit):
        return []

    async def recent_diaries(self, _plant_id, _limit):
        return []

    async def recent_diagnosis(self, _plant_id):
        return None

    async def add(self, instance):
        if isinstance(instance, (AIAction, AIToolCall)) and instance.created_at is None:
            instance.created_at = datetime.now(UTC)
        self.added.append(instance)

    async def action_owned(self, _action_id, _user_id, *, lock=False):
        return self.action


def test_tool_contract_never_accepts_user_or_plant_identifiers() -> None:
    for tool in TOOL_DEFINITIONS:
        properties = tool["parameters"].get("properties", {})
        assert "user_id" not in properties
        assert "plant_id" not in properties
        assert tool["strict"] is True


async def test_read_tool_uses_server_scoped_plant() -> None:
    repository = FakeToolRepository()
    service = AIToolService(repository)  # type: ignore[arg-type]

    output = await service.execute(
        call=ChatToolCall(call_id="call-1", name="get_plant_basic_info", arguments="{}"),
        message_id=uuid4(),
        user_id=uuid4(),
        plant_id=uuid4(),
    )

    assert json.loads(output)["species_name"] == "바질"
    audit = repository.added[0]
    assert isinstance(audit, AIToolCall)
    assert audit.status == ToolCallStatus.COMPLETED.value


async def test_care_proposal_only_creates_pending_action() -> None:
    repository = FakeToolRepository()
    service = AIToolService(repository)  # type: ignore[arg-type]
    due_date = date.today() + timedelta(days=2)

    output = await service.execute(
        call=ChatToolCall(
            call_id="call-2",
            name="propose_one_time_care",
            arguments=json.dumps(
                {
                    "care_type": "FERTILIZING",
                    "due_date": due_date.isoformat(),
                    "title": "비료 주기",
                    "reason": "생장기 권장",
                }
            ),
        ),
        message_id=uuid4(),
        user_id=uuid4(),
        plant_id=uuid4(),
    )

    result = json.loads(output)
    assert result["status"] == AIActionStatus.PENDING_CONFIRMATION.value
    assert not any(isinstance(item, CareEvent) for item in repository.added)
    assert any(isinstance(item, AIAction) for item in repository.added)


async def test_invalid_tool_arguments_are_audited_without_execution() -> None:
    repository = FakeToolRepository()
    service = AIToolService(repository)  # type: ignore[arg-type]

    output = await service.execute(
        call=ChatToolCall(
            call_id="call-3",
            name="get_recent_care_history",
            arguments='{"limit": 999}',
        ),
        message_id=uuid4(),
        user_id=uuid4(),
        plant_id=uuid4(),
    )

    assert json.loads(output)["ok"] is False
    audit = repository.added[0]
    assert isinstance(audit, AIToolCall)
    assert audit.status == ToolCallStatus.FAILED.value
    assert audit.error_code == "INVALID_TOOL_ARGUMENTS"


async def test_confirm_action_creates_one_time_event() -> None:
    now = datetime.now(UTC)
    action = AIAction(
        id=uuid4(),
        user_id=uuid4(),
        message_id=uuid4(),
        plant_id=uuid4(),
        action_type="CREATE_ONE_TIME_CARE_EVENT",
        payload={
            "care_type": "PRUNING",
            "due_date": (date.today() + timedelta(days=1)).isoformat(),
            "title": "가지치기",
            "reason": "마른 잎 정리",
        },
        status=AIActionStatus.PENDING_CONFIRMATION.value,
        expires_at=now + timedelta(hours=1),
        created_at=now,
    )
    repository = FakeToolRepository(action=action)

    response = await AIActionService(repository).confirm(action.user_id, action.id)  # type: ignore[arg-type]

    event = next(item for item in repository.added if isinstance(item, CareEvent))
    assert event.type == "PRUNING"
    assert event.status == CareEventStatus.SCHEDULED.value
    assert event.source == CareEventSource.AI_RECOMMENDED.value
    assert response.status == AIActionStatus.COMPLETED


async def test_confirm_rejects_non_pending_action() -> None:
    now = datetime.now(UTC)
    action = AIAction(
        id=uuid4(),
        user_id=uuid4(),
        message_id=uuid4(),
        plant_id=uuid4(),
        action_type="CREATE_ONE_TIME_CARE_EVENT",
        payload={},
        status=AIActionStatus.CANCELLED.value,
        created_at=now,
    )

    with pytest.raises(AppError) as error:
        await AIActionService(FakeToolRepository(action=action)).confirm(  # type: ignore[arg-type]
            action.user_id, action.id
        )

    assert error.value.code == "AI_ACTION_NOT_PENDING"


async def test_action_from_another_user_is_hidden() -> None:
    with pytest.raises(AppError) as error:
        await AIActionService(FakeToolRepository(action=None)).cancel(  # type: ignore[arg-type]
            uuid4(), uuid4()
        )

    assert error.value.code == "AI_ACTION_NOT_FOUND"
