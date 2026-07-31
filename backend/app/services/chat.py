import asyncio
import base64
import binascii
import json
from collections.abc import AsyncIterator
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.integrations.openai_chat import (
    ChatCompletion,
    ChatInputMessage,
    ChatStreamEvent,
    OpenAIChatProvider,
)
from app.models.chat import AIConversation, AIMessage
from app.models.enums import AIMessageStatus, ChatRole, MediaPurpose, MediaStatus
from app.models.media import MediaFile
from app.models.plant import Plant, SpeciesCareGuide
from app.schemas.chat import (
    ConversationListResponse,
    ConversationResponse,
    MessageAcceptedResponse,
    MessageCreateRequest,
    MessageListResponse,
    MessageResponse,
)


@dataclass(frozen=True, slots=True)
class PlantChatContext:
    user_id: UUID
    plant_id: UUID
    nickname: str
    place_name: str
    pot_type: str
    placement: str
    species_name: str
    scientific_name: str | None
    care_profile: dict


@dataclass(frozen=True, slots=True)
class PreparedTextMessage:
    assistant_message_id: UUID
    instructions: str
    messages: list[ChatInputMessage]


@dataclass(frozen=True, slots=True)
class PreparedMessage:
    accepted: MessageAcceptedResponse
    text: PreparedTextMessage | None


class ChatRepository(Protocol):
    async def plant_context_owned(
        self, plant_id: UUID, user_id: UUID
    ) -> PlantChatContext | None: ...

    async def create_conversation(self, conversation: AIConversation) -> None: ...

    async def list_conversations(
        self, plant_id: UUID, query: str | None, offset: int, limit: int
    ) -> list[AIConversation]: ...

    async def conversation_owned(
        self, conversation_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> AIConversation | None: ...

    async def list_messages(
        self, conversation_id: UUID, offset: int, limit: int
    ) -> list[AIMessage]: ...

    async def has_in_flight_message(self, conversation_id: UUID) -> bool: ...

    async def media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None: ...

    async def add_message(self, message: AIMessage) -> None: ...

    async def recent_context_messages(
        self, conversation: AIConversation, limit: int
    ) -> list[AIMessage]: ...

    async def complete_assistant(self, message_id: UUID, completion: ChatCompletion) -> None: ...

    async def fail_assistant(self, message_id: UUID) -> None: ...

    async def summary_batch(
        self, conversation: AIConversation, trigger_count: int, batch_size: int
    ) -> list[AIMessage]: ...

    async def save_summary(
        self, conversation: AIConversation, summary: str, through_message_id: UUID
    ) -> None: ...


class SQLAlchemyChatRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def plant_context_owned(self, plant_id: UUID, user_id: UUID) -> PlantChatContext | None:
        row = (
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
        if row is None:
            return None
        plant, guide = row
        return PlantChatContext(
            user_id=user_id,
            plant_id=plant.id,
            nickname=plant.nickname,
            place_name=plant.place_name,
            pot_type=plant.pot_type,
            placement=plant.placement,
            species_name=guide.display_name,
            scientific_name=guide.scientific_name,
            care_profile=guide.care_profile or {},
        )

    async def create_conversation(self, conversation: AIConversation) -> None:
        self._session.add(conversation)
        await self._session.flush()

    async def list_conversations(
        self, plant_id: UUID, query: str | None, offset: int, limit: int
    ) -> list[AIConversation]:
        statement = select(AIConversation).where(
            AIConversation.plant_id == plant_id,
            AIConversation.deleted_at.is_(None),
        )
        if query:
            escaped = query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            statement = statement.where(AIConversation.title.ilike(f"%{escaped}%", escape="\\"))
        statement = statement.order_by(
            AIConversation.last_message_at.desc().nullslast(),
            AIConversation.created_at.desc(),
        )
        return list((await self._session.scalars(statement.offset(offset).limit(limit))).all())

    async def conversation_owned(
        self, conversation_id: UUID, user_id: UUID, *, lock: bool = False
    ) -> AIConversation | None:
        statement = (
            select(AIConversation)
            .join(Plant, Plant.id == AIConversation.plant_id)
            .where(
                AIConversation.id == conversation_id,
                AIConversation.deleted_at.is_(None),
                Plant.user_id == user_id,
                Plant.deleted_at.is_(None),
            )
        )
        if lock:
            statement = statement.with_for_update(of=AIConversation)
        return await self._session.scalar(statement)

    async def list_messages(
        self, conversation_id: UUID, offset: int, limit: int
    ) -> list[AIMessage]:
        statement = (
            select(AIMessage)
            .where(AIMessage.conversation_id == conversation_id)
            .order_by(AIMessage.created_at.desc(), AIMessage.id.desc())
            .offset(offset)
            .limit(limit)
        )
        return list((await self._session.scalars(statement)).all())

    async def has_in_flight_message(self, conversation_id: UUID) -> bool:
        return bool(
            await self._session.scalar(
                select(AIMessage.id).where(
                    AIMessage.conversation_id == conversation_id,
                    AIMessage.status.in_(
                        [AIMessageStatus.PENDING.value, AIMessageStatus.PROCESSING.value]
                    ),
                )
            )
        )

    async def media_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None:
        return await self._session.scalar(
            select(MediaFile).where(
                MediaFile.id == media_file_id,
                MediaFile.user_id == user_id,
                MediaFile.deleted_at.is_(None),
            )
        )

    async def add_message(self, message: AIMessage) -> None:
        self._session.add(message)
        await self._session.flush()

    async def recent_context_messages(
        self, conversation: AIConversation, limit: int
    ) -> list[AIMessage]:
        statement = select(AIMessage).where(
            AIMessage.conversation_id == conversation.id,
            AIMessage.status == AIMessageStatus.COMPLETED.value,
            AIMessage.role.in_([ChatRole.USER.value, ChatRole.ASSISTANT.value]),
        )
        if conversation.summarized_through_message_id:
            marker = await self._session.get(AIMessage, conversation.summarized_through_message_id)
            if marker is not None:
                statement = statement.where(AIMessage.created_at > marker.created_at)
        newest = (
            statement.order_by(AIMessage.created_at.desc(), AIMessage.id.desc())
            .limit(limit)
            .subquery()
        )
        return list(
            (
                await self._session.scalars(
                    select(AIMessage)
                    .join(newest, newest.c.id == AIMessage.id)
                    .order_by(AIMessage.created_at, AIMessage.id)
                )
            ).all()
        )

    async def complete_assistant(self, message_id: UUID, completion: ChatCompletion) -> None:
        message = await self._session.get(AIMessage, message_id)
        if message is None or message.status != AIMessageStatus.PROCESSING:
            return
        message.content = completion.content
        message.status = AIMessageStatus.COMPLETED.value
        message.provider = "OPENAI"
        message.model_name = completion.model_name
        message.provider_response_id = completion.response_id
        message.input_tokens = completion.input_tokens
        message.output_tokens = completion.output_tokens
        conversation = await self._session.get(AIConversation, message.conversation_id)
        if conversation is not None:
            conversation.last_message_at = datetime.now(UTC)

    async def fail_assistant(self, message_id: UUID) -> None:
        message = await self._session.get(AIMessage, message_id)
        if message is not None and message.status == AIMessageStatus.PROCESSING:
            message.status = AIMessageStatus.FAILED.value

    async def summary_batch(
        self, conversation: AIConversation, trigger_count: int, batch_size: int
    ) -> list[AIMessage]:
        statement = select(AIMessage).where(
            AIMessage.conversation_id == conversation.id,
            AIMessage.status == AIMessageStatus.COMPLETED.value,
            AIMessage.role.in_([ChatRole.USER.value, ChatRole.ASSISTANT.value]),
        )
        if conversation.summarized_through_message_id:
            marker = await self._session.get(AIMessage, conversation.summarized_through_message_id)
            if marker is not None:
                statement = statement.where(AIMessage.created_at > marker.created_at)
        count = await self._session.scalar(select(func.count()).select_from(statement.subquery()))
        if (count or 0) < trigger_count:
            return []
        return list(
            (
                await self._session.scalars(
                    statement.order_by(AIMessage.created_at, AIMessage.id).limit(batch_size)
                )
            ).all()
        )

    async def save_summary(
        self, conversation: AIConversation, summary: str, through_message_id: UUID
    ) -> None:
        conversation.context_summary = summary
        conversation.summarized_through_message_id = through_message_id
        conversation.summary_version += 1
        conversation.summary_updated_at = datetime.now(UTC)


class ChatService:
    def __init__(
        self,
        repository: ChatRepository,
        provider: OpenAIChatProvider,
        *,
        context_message_limit: int,
        summary_trigger_count: int,
        summary_batch_size: int,
    ) -> None:
        self._repository = repository
        self._provider = provider
        self._context_message_limit = context_message_limit
        self._summary_trigger_count = summary_trigger_count
        self._summary_batch_size = summary_batch_size

    async def create_conversation(
        self, user_id: UUID, plant_id: UUID, title: str
    ) -> ConversationResponse:
        await self._require_plant_context(user_id, plant_id)
        conversation = AIConversation(
            id=uuid4(),
            plant_id=plant_id,
            title=title.strip(),
            summary_version=0,
        )
        await self._repository.create_conversation(conversation)
        return conversation_to_response(conversation)

    async def list_conversations(
        self,
        user_id: UUID,
        plant_id: UUID,
        query: str | None,
        cursor: str | None,
        limit: int,
    ) -> ConversationListResponse:
        await self._require_plant_context(user_id, plant_id)
        offset = decode_cursor(cursor)
        normalized_query = query.strip() if query else None
        conversations = await self._repository.list_conversations(
            plant_id, normalized_query, offset, limit + 1
        )
        has_next = len(conversations) > limit
        return ConversationListResponse(
            items=[conversation_to_response(item) for item in conversations[:limit]],
            has_next=has_next,
            next_cursor=encode_cursor(offset + limit) if has_next else None,
        )

    async def delete_conversation(self, user_id: UUID, conversation_id: UUID) -> None:
        conversation = await self._require_conversation(user_id, conversation_id, lock=True)
        if await self._repository.has_in_flight_message(conversation.id):
            raise AppError(
                code="CHAT_MESSAGE_IN_PROGRESS",
                message="응답 생성이 끝난 뒤 대화를 삭제해 주세요.",
                status_code=409,
            )
        conversation.deleted_at = datetime.now(UTC)

    async def list_messages(
        self, user_id: UUID, conversation_id: UUID, cursor: str | None, limit: int
    ) -> MessageListResponse:
        await self._require_conversation(user_id, conversation_id)
        offset = decode_cursor(cursor)
        messages = await self._repository.list_messages(conversation_id, offset, limit + 1)
        has_next = len(messages) > limit
        return MessageListResponse(
            items=[message_to_response(item) for item in reversed(messages[:limit])],
            has_next=has_next,
            next_cursor=encode_cursor(offset + limit) if has_next else None,
        )

    async def prepare_message(
        self, user_id: UUID, conversation_id: UUID, request: MessageCreateRequest
    ) -> PreparedMessage:
        self._provider.ensure_configured()
        conversation = await self._require_conversation(user_id, conversation_id, lock=True)
        if await self._repository.has_in_flight_message(conversation.id):
            raise AppError(
                code="CHAT_MESSAGE_IN_PROGRESS",
                message="이전 응답을 생성하고 있습니다.",
                status_code=409,
            )
        context = await self._require_plant_context(user_id, conversation.plant_id)
        if request.media_file_id is not None:
            await self._validate_chat_media(user_id, request.media_file_id)

        user_message = AIMessage(
            id=uuid4(),
            conversation_id=conversation.id,
            media_file_id=request.media_file_id,
            role=ChatRole.USER.value,
            status=(
                AIMessageStatus.PENDING.value
                if request.media_file_id
                else AIMessageStatus.COMPLETED.value
            ),
            content=request.content,
        )
        await self._repository.add_message(user_message)
        if conversation.title == "새 채팅":
            conversation.title = make_conversation_title(
                request.content,
                has_media=request.media_file_id is not None,
            )
        conversation.last_message_at = datetime.now(UTC)
        accepted = MessageAcceptedResponse(
            message_id=user_message.id,
            status=AIMessageStatus(user_message.status),
        )
        if request.media_file_id is not None:
            return PreparedMessage(accepted=accepted, text=None)

        assistant = AIMessage(
            id=uuid4(),
            conversation_id=conversation.id,
            role=ChatRole.ASSISTANT.value,
            status=AIMessageStatus.PROCESSING.value,
            content="",
            provider=self._provider.provider_name,
            model_name=self._provider.model_name,
        )
        await self._repository.add_message(assistant)
        recent = await self._repository.recent_context_messages(
            conversation, self._context_message_limit
        )
        return PreparedMessage(
            accepted=accepted,
            text=PreparedTextMessage(
                assistant_message_id=assistant.id,
                instructions=build_instructions(context, conversation.context_summary),
                messages=[model_to_input(item) for item in recent],
            ),
        )

    async def stream_text_reply(
        self,
        *,
        user_id: UUID,
        conversation_id: UUID,
        prepared: PreparedTextMessage,
    ) -> AsyncIterator[ChatStreamEvent]:
        try:
            async for event in self._provider.stream_reply(
                instructions=prepared.instructions,
                messages=prepared.messages,
                safety_user_id=str(user_id),
            ):
                if event.completion is not None:
                    await self._repository.complete_assistant(
                        prepared.assistant_message_id, event.completion
                    )
                yield event
                if event.completion is not None:
                    await self._summarize_if_needed(user_id, conversation_id)
        except asyncio.CancelledError:
            await self._repository.fail_assistant(prepared.assistant_message_id)
            raise
        except Exception:
            await self._repository.fail_assistant(prepared.assistant_message_id)
            raise

    async def _summarize_if_needed(self, user_id: UUID, conversation_id: UUID) -> None:
        conversation = await self._require_conversation(user_id, conversation_id)
        batch = await self._repository.summary_batch(
            conversation,
            self._summary_trigger_count,
            self._summary_batch_size,
        )
        if not batch:
            return
        try:
            summary = await self._provider.summarize(
                current_summary=conversation.context_summary,
                messages=[model_to_input(item) for item in batch],
                safety_user_id=str(user_id),
            )
        except Exception:
            return
        await self._repository.save_summary(conversation, summary, batch[-1].id)

    async def _validate_chat_media(self, user_id: UUID, media_file_id: UUID) -> None:
        media = await self._repository.media_owned(media_file_id, user_id)
        if media is None:
            raise AppError(
                code="MEDIA_FILE_NOT_FOUND",
                message="파일을 찾을 수 없습니다.",
                status_code=404,
            )
        if media.purpose != MediaPurpose.CHAT:
            raise AppError(
                code="MEDIA_PURPOSE_MISMATCH",
                message="채팅용으로 업로드한 사진이 아닙니다.",
                status_code=409,
            )
        if media.status != MediaStatus.READY:
            raise AppError(
                code="MEDIA_NOT_READY",
                message="아직 사용할 수 없는 파일입니다.",
                status_code=409,
            )
        if not media.content_type.startswith("image/"):
            raise AppError(
                code="MEDIA_TYPE_NOT_ALLOWED",
                message="이미지 파일만 첨부할 수 있습니다.",
                status_code=422,
            )

    async def _require_plant_context(self, user_id: UUID, plant_id: UUID) -> PlantChatContext:
        context = await self._repository.plant_context_owned(plant_id, user_id)
        if context is None:
            raise AppError(
                code="PLANT_NOT_FOUND",
                message="식물을 찾을 수 없습니다.",
                status_code=404,
            )
        return context

    async def _require_conversation(
        self, user_id: UUID, conversation_id: UUID, *, lock: bool = False
    ) -> AIConversation:
        conversation = await self._repository.conversation_owned(
            conversation_id, user_id, lock=lock
        )
        if conversation is None:
            raise AppError(
                code="CONVERSATION_NOT_FOUND",
                message="대화를 찾을 수 없습니다.",
                status_code=404,
            )
        return conversation


def build_instructions(context: PlantChatContext, summary: str | None) -> str:
    return (
        "당신은 친근하고 신중한 AI 식물박사 '똑똑이'입니다. 한국어로 답하세요. "
        "식물 관리 질문에는 결론, 근거, 다음 행동 순서로 간결하게 답하세요. "
        "사진만으로 질병을 확정하지 말고 불확실하면 추가 관찰이나 전문가 확인을 권하세요. "
        f"상담 대상 식물의 애칭: {context.nickname}, 식물명: {context.species_name}, "
        f"학명: {context.scientific_name or '미상'}, "
        f"장소: {context.place_name}, 화분: {context.pot_type}, 위치: {context.placement}. "
        f"관리 가이드: {json.dumps(context.care_profile, ensure_ascii=False)}. "
        f"이전 대화 요약: {summary or '없음'}."
    )


def make_conversation_title(content: str, *, has_media: bool) -> str:
    normalized = " ".join(content.split())
    if not normalized:
        return "사진 질문" if has_media else "새 채팅"
    return normalized[:30]


def model_to_input(message: AIMessage) -> ChatInputMessage:
    return ChatInputMessage(role=message.role, content=message.content)


def conversation_to_response(conversation: AIConversation) -> ConversationResponse:
    return ConversationResponse(
        id=conversation.id,
        plant_id=conversation.plant_id,
        title=conversation.title,
        last_message_at=conversation.last_message_at,
        created_at=conversation.created_at,
    )


def message_to_response(message: AIMessage) -> MessageResponse:
    return MessageResponse(
        id=message.id,
        conversation_id=message.conversation_id,
        related_diagnosis_id=message.related_diagnosis_id,
        media_file_id=message.media_file_id,
        role=ChatRole(message.role),
        status=AIMessageStatus(message.status),
        content=message.content,
        provider=message.provider,
        model_name=message.model_name,
        created_at=message.created_at,
    )


def encode_cursor(offset: int) -> str:
    return base64.urlsafe_b64encode(str(offset).encode()).decode().rstrip("=")


def decode_cursor(cursor: str | None) -> int:
    if cursor is None:
        return 0
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        offset = int(base64.urlsafe_b64decode(padded).decode())
    except (binascii.Error, ValueError, UnicodeDecodeError) as exc:
        raise AppError(
            code="INVALID_CURSOR",
            message="페이지 정보를 확인해 주세요.",
            status_code=422,
        ) from exc
    if offset < 0:
        raise AppError(
            code="INVALID_CURSOR",
            message="페이지 정보를 확인해 주세요.",
            status_code=422,
        )
    return offset
