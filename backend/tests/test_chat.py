import asyncio
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.config import Settings
from app.core.errors import AppError
from app.integrations.openai_chat import (
    ChatInputMessage,
    ChatToolCall,
    ChatToolTurn,
    OpenAIChatProvider,
)
from app.main import create_app
from app.models.chat import AIConversation, AIMessage
from app.models.enums import AIMessageStatus, ChatRole
from app.schemas.chat import MessageCreateRequest
from app.services.chat import (
    ChatService,
    PlantChatContext,
    PreparedTextMessage,
    build_instructions,
    decode_cursor,
    encode_cursor,
    make_conversation_title,
)


def test_message_requires_text_or_photo() -> None:
    with pytest.raises(ValidationError):
        MessageCreateRequest()

    assert MessageCreateRequest(client_message_id=uuid4(), content="  안녕  ").content == "안녕"
    assert MessageCreateRequest(client_message_id=uuid4(), media_file_id=uuid4()).content == ""


def test_chat_cursor_round_trip_and_validation() -> None:
    assert decode_cursor(encode_cursor(42)) == 42

    with pytest.raises(AppError) as error:
        decode_cursor("not-a-cursor")

    assert error.value.code == "INVALID_CURSOR"


def test_chat_provider_requires_api_key() -> None:
    provider = OpenAIChatProvider(Settings(openai_api_key=""))

    with pytest.raises(AppError) as error:
        provider.ensure_configured()

    assert error.value.code == "AI_PROVIDER_NOT_CONFIGURED"


async def test_chat_provider_uses_supported_gpt5_mini_reasoning_effort() -> None:
    class FakeStream:
        def __init__(self) -> None:
            self._events = iter(
                [
                    SimpleNamespace(type="response.output_text.delta", delta="답변"),
                    SimpleNamespace(
                        type="response.completed",
                        response=SimpleNamespace(
                            output_text="답변",
                            id="response_1",
                            model="gpt-5-mini",
                            usage=SimpleNamespace(input_tokens=1, output_tokens=1),
                        ),
                    ),
                ]
            )

        def __aiter__(self):
            return self

        async def __anext__(self):
            try:
                return next(self._events)
            except StopIteration as exc:
                raise StopAsyncIteration from exc

    class FakeResponses:
        def __init__(self) -> None:
            self.kwargs: dict | None = None

        async def create(self, **kwargs):
            self.kwargs = kwargs
            return FakeStream()

    responses = FakeResponses()
    client = SimpleNamespace(responses=responses)
    provider = OpenAIChatProvider(
        Settings(_env_file=None, openai_chat_model="gpt-5-mini"),
        client=client,  # type: ignore[arg-type]
    )

    events = [
        event
        async for event in provider.stream_reply(
            instructions="짧게 답하세요.",
            messages=[ChatInputMessage(role="user", content="안녕")],
            safety_user_id="user-1",
        )
    ]

    assert responses.kwargs is not None
    assert responses.kwargs["reasoning"] == {"effort": "minimal"}
    assert events[-1].completion is not None


async def test_chat_provider_parses_function_calls_for_stateless_tool_loop() -> None:
    class FunctionCall:
        type = "function_call"
        call_id = "call-1"
        name = "get_plant_basic_info"
        arguments = "{}"

        def model_dump(self, **_kwargs):
            return {
                "type": self.type,
                "call_id": self.call_id,
                "name": self.name,
                "arguments": self.arguments,
            }

    class FakeResponses:
        def __init__(self) -> None:
            self.kwargs = None

        async def create(self, **kwargs):
            self.kwargs = kwargs
            return SimpleNamespace(
                output=[FunctionCall()],
                output_text="",
                id="response-1",
                model="gpt-5-mini",
                usage=SimpleNamespace(input_tokens=2, output_tokens=3),
            )

    responses = FakeResponses()
    provider = OpenAIChatProvider(
        Settings(_env_file=None, openai_chat_model="gpt-5-mini"),
        client=SimpleNamespace(responses=responses),  # type: ignore[arg-type]
    )

    turn = await provider.create_tool_turn(
        instructions="도구를 사용하세요.",
        input_items=[{"role": "user", "content": "내 식물은?"}],
        tools=[
            {
                "type": "function",
                "name": "get_plant_basic_info",
                "parameters": {"type": "object", "properties": {}},
            }
        ],
        safety_user_id="user-1",
    )

    assert turn.tool_calls[0].name == "get_plant_basic_info"
    assert responses.kwargs["store"] is False
    assert responses.kwargs["include"] == ["reasoning.encrypted_content"]


def test_chat_routes_require_authentication() -> None:
    identifier = uuid4()
    application = create_app()

    with TestClient(application) as client:
        responses = [
            client.get(f"/api/v1/plants/{identifier}/conversations"),
            client.get(f"/api/v1/conversations/{identifier}/messages"),
            client.post(f"/api/v1/ai-actions/{identifier}/confirm"),
            client.post(f"/api/v1/ai-actions/{identifier}/cancel"),
        ]

    assert [response.status_code for response in responses] == [401, 401, 401, 401]


async def test_chat_rejects_unowned_plant() -> None:
    class MissingPlantRepository:
        async def plant_context_owned(self, _plant_id, _user_id):
            return None

    from app.services.chat import ChatService

    service = ChatService(
        MissingPlantRepository(),  # type: ignore[arg-type]
        OpenAIChatProvider(Settings(openai_api_key="")),
        context_message_limit=20,
        summary_trigger_count=30,
        summary_batch_size=20,
    )

    with pytest.raises(AppError) as error:
        await service.create_conversation(uuid4(), uuid4(), "새 채팅")

    assert error.value.code == "PLANT_NOT_FOUND"


async def test_duplicate_client_message_id_reuses_existing_message() -> None:
    user_id = uuid4()
    client_message_id = uuid4()
    conversation = AIConversation(id=uuid4(), plant_id=uuid4(), title="질문", summary_version=0)
    existing = AIMessage(
        id=uuid4(),
        conversation_id=conversation.id,
        client_message_id=client_message_id,
        role=ChatRole.USER.value,
        status=AIMessageStatus.COMPLETED.value,
        content="물은 얼마나 줘?",
    )

    class Repository:
        async def conversation_owned(self, *_args, **_kwargs):
            return conversation

        async def message_by_client_id(self, *_args):
            return existing

    class Provider:
        provider_name = "OPENAI"
        model_name = "gpt-5-mini"

        def ensure_configured(self):
            return None

    service = ChatService(
        Repository(),  # type: ignore[arg-type]
        Provider(),  # type: ignore[arg-type]
        context_message_limit=20,
        summary_trigger_count=30,
        summary_batch_size=20,
    )

    prepared = await service.prepare_message(
        user_id,
        conversation.id,
        MessageCreateRequest(client_message_id=client_message_id, content="물은 얼마나 줘?"),
    )

    assert prepared.duplicate is True
    assert prepared.accepted.message_id == existing.id

    with pytest.raises(AppError) as error:
        await service.prepare_message(
            user_id,
            conversation.id,
            MessageCreateRequest(client_message_id=client_message_id, content="다른 질문"),
        )

    assert error.value.code == "CLIENT_MESSAGE_ID_REUSED"


async def test_cancelled_stream_marks_assistant_failed() -> None:
    assistant_id = uuid4()

    class Repository:
        failed: list = []

        async def fail_assistant(self, message_id):
            self.failed.append(message_id)

    class Provider:
        async def stream_reply(self, **_kwargs):
            raise asyncio.CancelledError
            yield  # pragma: no cover

    repository = Repository()
    service = ChatService(
        repository,  # type: ignore[arg-type]
        Provider(),  # type: ignore[arg-type]
        context_message_limit=20,
        summary_trigger_count=30,
        summary_batch_size=20,
    )

    with pytest.raises(asyncio.CancelledError):
        async for _ in service.stream_text_reply(
            user_id=uuid4(),
            conversation_id=uuid4(),
            prepared=PreparedTextMessage(
                assistant_message_id=assistant_id,
                instructions="답하세요.",
                messages=[],
            ),
        ):
            pass

    assert repository.failed == [assistant_id]


def test_chat_prompt_uses_ai_doctor_identity() -> None:
    context = PlantChatContext(
        user_id=uuid4(),
        plant_id=uuid4(),
        nickname="새싹이",
        place_name="우리 집",
        pot_type="PLASTIC",
        placement="WINDOW",
        species_name="바질",
        scientific_name="Ocimum basilicum",
        care_profile={},
    )

    instructions = build_instructions(context, None)

    assert "AI 식물박사 '똑똑이'" in instructions
    assert "상담 대상 식물의 애칭: 새싹이" in instructions


def test_first_message_creates_conversation_list_title() -> None:
    assert make_conversation_title("  물은   얼마나 줘야 하나요?  ", has_media=False) == (
        "물은 얼마나 줘야 하나요?"
    )
    assert make_conversation_title("", has_media=True) == "사진 질문"
    assert len(make_conversation_title("가" * 50, has_media=False)) == 30


async def test_chat_runs_tool_and_returns_its_output_to_model() -> None:
    user_id = uuid4()
    plant_id = uuid4()
    conversation = AIConversation(
        id=uuid4(),
        plant_id=plant_id,
        title="질문",
        summary_version=0,
    )

    class FakeRepository:
        def __init__(self) -> None:
            self.completion = None

        async def conversation_owned(self, _conversation_id, _user_id, *, lock=False):
            return conversation

        async def complete_assistant(self, _message_id, completion):
            self.completion = completion

        async def summary_batch(self, _conversation, _trigger_count, _batch_size):
            return []

    class FakeProvider:
        def __init__(self) -> None:
            self.inputs: list[list[dict]] = []

        async def create_tool_turn(self, **kwargs):
            self.inputs.append(list(kwargs["input_items"]))
            if len(self.inputs) == 1:
                return ChatToolTurn(
                    content="",
                    response_id="response-1",
                    model_name="gpt-5-mini",
                    input_tokens=10,
                    output_tokens=3,
                    output_items=[
                        {
                            "type": "function_call",
                            "call_id": "call-1",
                            "name": "get_plant_basic_info",
                            "arguments": "{}",
                        }
                    ],
                    tool_calls=[
                        ChatToolCall(
                            call_id="call-1",
                            name="get_plant_basic_info",
                            arguments="{}",
                        )
                    ],
                )
            return ChatToolTurn(
                content="바질은 밝은 곳에서 키워 주세요.",
                response_id="response-2",
                model_name="gpt-5-mini",
                input_tokens=12,
                output_tokens=8,
                output_items=[],
                tool_calls=[],
            )

    class FakeToolService:
        async def execute(self, **_kwargs):
            return '{"species_name":"바질"}'

    repository = FakeRepository()
    provider = FakeProvider()
    service = ChatService(
        repository,  # type: ignore[arg-type]
        provider,  # type: ignore[arg-type]
        context_message_limit=20,
        summary_trigger_count=30,
        summary_batch_size=20,
        tool_service=FakeToolService(),  # type: ignore[arg-type]
    )

    events = [
        event
        async for event in service.stream_text_reply(
            user_id=user_id,
            conversation_id=conversation.id,
            prepared=PreparedTextMessage(
                assistant_message_id=uuid4(),
                instructions="답하세요.",
                messages=[ChatInputMessage(role="USER", content="이 식물은 뭐야?")],
            ),
        )
    ]

    assert provider.inputs[1][-1] == {
        "type": "function_call_output",
        "call_id": "call-1",
        "output": '{"species_name":"바질"}',
    }
    assert events[-1].completion is not None
    assert repository.completion.input_tokens == 22
