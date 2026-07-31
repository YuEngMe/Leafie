from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.config import Settings
from app.core.errors import AppError
from app.integrations.openai_chat import OpenAIChatProvider
from app.main import create_app
from app.schemas.chat import MessageCreateRequest
from app.services.chat import (
    PlantChatContext,
    build_instructions,
    decode_cursor,
    encode_cursor,
    make_conversation_title,
)


def test_message_requires_text_or_photo() -> None:
    with pytest.raises(ValidationError):
        MessageCreateRequest()

    assert MessageCreateRequest(content="  안녕  ").content == "안녕"
    assert MessageCreateRequest(media_file_id=uuid4()).content == ""


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


def test_chat_routes_require_authentication() -> None:
    identifier = uuid4()
    application = create_app()

    with TestClient(application) as client:
        responses = [
            client.get(f"/api/v1/plants/{identifier}/conversations"),
            client.get(f"/api/v1/conversations/{identifier}/messages"),
        ]

    assert [response.status_code for response in responses] == [401, 401]


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
