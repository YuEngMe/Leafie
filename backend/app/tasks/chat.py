from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import select

from app.core.errors import AppError
from app.db.session import Database
from app.integrations.openai_chat import (
    ChatCompletion,
    ChatInputMessage,
    OpenAIChatPermanentError,
    OpenAIChatProvider,
)
from app.integrations.storage import StorageGateway
from app.models.chat import AIConversation, AIMessage
from app.models.enums import AIMessageStatus, ChatRole
from app.models.media import MediaFile
from app.models.plant import Plant, SpeciesCareGuide
from app.schemas.queue import QueueJob
from app.services.chat import PlantChatContext, build_instructions
from app.tasks.base import PermanentTaskError


@dataclass(frozen=True, slots=True)
class ChatImageWork:
    user_id: UUID
    conversation_id: UUID
    object_path: str
    content_type: str
    caption: str
    instructions: str
    messages: list[ChatInputMessage]


class ChatImageRepository(Protocol):
    async def start(self, message_id: UUID) -> ChatImageWork | None: ...

    async def complete(self, message_id: UUID, completion: ChatCompletion) -> None: ...

    async def release_for_retry(self, message_id: UUID) -> None: ...

    async def fail(self, message_id: UUID) -> None: ...


class SQLAlchemyChatImageRepository:
    def __init__(self, database: Database, *, context_limit: int) -> None:
        self._database = database
        self._context_limit = context_limit

    async def start(self, message_id: UUID) -> ChatImageWork | None:
        async with self._database.session_context() as session:
            row = (
                await session.execute(
                    select(AIMessage, AIConversation, Plant, SpeciesCareGuide, MediaFile)
                    .join(AIConversation, AIConversation.id == AIMessage.conversation_id)
                    .join(Plant, Plant.id == AIConversation.plant_id)
                    .join(
                        SpeciesCareGuide,
                        SpeciesCareGuide.species_reference_id == Plant.species_reference_id,
                    )
                    .join(MediaFile, MediaFile.id == AIMessage.media_file_id)
                    .where(AIMessage.id == message_id)
                    .with_for_update(of=AIMessage)
                )
            ).one_or_none()
            if row is None:
                return None
            message, conversation, plant, guide, media = row
            if message.status != AIMessageStatus.PENDING.value:
                return None
            message.status = AIMessageStatus.PROCESSING.value
            recent = list(
                (
                    await session.scalars(
                        select(AIMessage)
                        .where(
                            AIMessage.conversation_id == conversation.id,
                            AIMessage.status == AIMessageStatus.COMPLETED.value,
                            AIMessage.role.in_([ChatRole.USER.value, ChatRole.ASSISTANT.value]),
                        )
                        .order_by(AIMessage.created_at.desc(), AIMessage.id.desc())
                        .limit(self._context_limit)
                    )
                ).all()
            )
            context = PlantChatContext(
                user_id=plant.user_id,
                plant_id=plant.id,
                nickname=plant.nickname,
                place_name=plant.place_name,
                pot_type=plant.pot_type,
                placement=plant.placement,
                species_name=guide.display_name,
                scientific_name=guide.scientific_name,
                care_profile=guide.care_profile or {},
            )
            return ChatImageWork(
                user_id=plant.user_id,
                conversation_id=conversation.id,
                object_path=media.object_path,
                content_type=media.content_type,
                caption=message.content,
                instructions=build_instructions(context, conversation.context_summary),
                messages=[
                    ChatInputMessage(role=item.role, content=item.content)
                    for item in reversed(recent)
                ],
            )

    async def complete(self, message_id: UUID, completion: ChatCompletion) -> None:
        async with self._database.session_context() as session:
            message = await session.scalar(
                select(AIMessage).where(AIMessage.id == message_id).with_for_update()
            )
            if message is None or message.status != AIMessageStatus.PROCESSING.value:
                return
            message.status = AIMessageStatus.COMPLETED.value
            session.add(
                AIMessage(
                    id=uuid4(),
                    conversation_id=message.conversation_id,
                    role=ChatRole.ASSISTANT.value,
                    status=AIMessageStatus.COMPLETED.value,
                    content=completion.content,
                    provider="OPENAI",
                    model_name=completion.model_name,
                    provider_response_id=completion.response_id,
                    input_tokens=completion.input_tokens,
                    output_tokens=completion.output_tokens,
                )
            )
            conversation = await session.get(AIConversation, message.conversation_id)
            if conversation is not None:
                conversation.last_message_at = datetime.now(UTC)

    async def release_for_retry(self, message_id: UUID) -> None:
        await self._set_status(
            message_id,
            AIMessageStatus.PROCESSING,
            AIMessageStatus.PENDING,
        )

    async def fail(self, message_id: UUID) -> None:
        async with self._database.session_context() as session:
            message = await session.get(AIMessage, message_id)
            if message is not None and message.status in {
                AIMessageStatus.PENDING.value,
                AIMessageStatus.PROCESSING.value,
            }:
                message.status = AIMessageStatus.FAILED.value

    async def _set_status(
        self,
        message_id: UUID,
        current: AIMessageStatus,
        target: AIMessageStatus,
    ) -> None:
        async with self._database.session_context() as session:
            message = await session.get(AIMessage, message_id)
            if message is not None and message.status == current.value:
                message.status = target.value


class ChatImageAnalysisHandler:
    def __init__(
        self,
        repository: ChatImageRepository,
        storage: StorageGateway,
        provider: OpenAIChatProvider,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._provider = provider

    async def __call__(self, job: QueueJob) -> None:
        work = await self._repository.start(job.resource_id)
        if work is None:
            return
        try:
            image = await self._storage.download_object(work.object_path)
            completion = await self._provider.reply_with_image(
                instructions=work.instructions,
                messages=work.messages,
                image=image,
                content_type=work.content_type,
                caption=work.caption,
                safety_user_id=str(work.user_id),
            )
            await self._repository.complete(job.resource_id, completion)
        except OpenAIChatPermanentError as exc:
            await self._repository.fail(job.resource_id)
            raise PermanentTaskError(
                exc.failure_code,
                "AI 사진 분석을 완료할 수 없습니다.",
            ) from exc
        except AppError as exc:
            if exc.code in {"AI_PROVIDER_NOT_CONFIGURED", "MEDIA_UPLOAD_NOT_FOUND"}:
                await self._repository.fail(job.resource_id)
                raise PermanentTaskError(exc.code, exc.message) from exc
            await self._repository.release_for_retry(job.resource_id)
            raise
        except Exception:
            await self._repository.release_for_retry(job.resource_id)
            raise

    async def on_exhausted(self, job: QueueJob) -> None:
        await self._repository.fail(job.resource_id)
