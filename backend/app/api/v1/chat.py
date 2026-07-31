import json
from collections.abc import AsyncIterator
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse, StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    get_database_session,
    get_job_queue,
    get_openai_chat_provider,
)
from app.core.config import settings
from app.core.errors import AppError
from app.core.request_context import create_request_id, get_request_id
from app.core.security import AuthenticatedUser
from app.integrations.openai_chat import OpenAIChatPermanentError, OpenAIChatProvider
from app.integrations.queue import JobQueue
from app.schemas.chat import (
    ConversationCreateRequest,
    ConversationListResponse,
    ConversationResponse,
    MessageCreateRequest,
    MessageListResponse,
)
from app.schemas.queue import JobType, QueueJob
from app.services.chat import ChatService, SQLAlchemyChatRepository

router = APIRouter(tags=["chat"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]
Queue = Annotated[JobQueue, Depends(get_job_queue)]
ChatProvider = Annotated[OpenAIChatProvider, Depends(get_openai_chat_provider)]


def build_service(session: AsyncSession, provider: OpenAIChatProvider) -> ChatService:
    return ChatService(
        SQLAlchemyChatRepository(session),
        provider,
        context_message_limit=settings.ai_chat_context_message_limit,
        summary_trigger_count=settings.ai_chat_summary_trigger_count,
        summary_batch_size=settings.ai_chat_summary_batch_size,
    )


@router.get("/plants/{plant_id}/conversations", response_model=ConversationListResponse)
async def list_conversations(
    plant_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    provider: ChatProvider,
    query: Annotated[str | None, Query(max_length=200)] = None,
    cursor: Annotated[str | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> ConversationListResponse:
    return await build_service(session, provider).list_conversations(
        current_user.id, plant_id, query, cursor, limit
    )


@router.post(
    "/plants/{plant_id}/conversations",
    response_model=ConversationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_conversation(
    plant_id: UUID,
    request: ConversationCreateRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    provider: ChatProvider,
) -> ConversationResponse:
    return await build_service(session, provider).create_conversation(
        current_user.id, plant_id, request.title
    )


@router.delete("/conversations/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_conversation(
    conversation_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    provider: ChatProvider,
) -> Response:
    await build_service(session, provider).delete_conversation(current_user.id, conversation_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/conversations/{conversation_id}/messages",
    response_model=MessageListResponse,
)
async def list_messages(
    conversation_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    provider: ChatProvider,
    cursor: Annotated[str | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> MessageListResponse:
    return await build_service(session, provider).list_messages(
        current_user.id, conversation_id, cursor, limit
    )


@router.post("/conversations/{conversation_id}/messages", response_model=None)
async def create_message(
    conversation_id: UUID,
    request: MessageCreateRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    queue: Queue,
    provider: ChatProvider,
) -> StreamingResponse | JSONResponse:
    service = build_service(session, provider)
    prepared = await service.prepare_message(current_user.id, conversation_id, request)
    if prepared.text is None:
        await queue.enqueue(
            QueueJob(
                job_type=JobType.CHAT_IMAGE_ANALYSIS,
                resource_id=prepared.accepted.message_id,
                trace_id=get_request_id() or create_request_id(),
            ),
            session=session,
        )
        return JSONResponse(
            status_code=status.HTTP_202_ACCEPTED,
            content=jsonable_encoder(prepared.accepted),
        )

    await session.commit()

    async def events() -> AsyncIterator[str]:
        yield _sse(
            "message.started",
            {"message_id": str(prepared.text.assistant_message_id)},
        )
        try:
            async for event in service.stream_text_reply(
                user_id=current_user.id,
                conversation_id=conversation_id,
                prepared=prepared.text,
            ):
                if event.delta is not None:
                    yield _sse("message.delta", {"delta": event.delta})
                if event.completion is not None:
                    await session.commit()
                    yield _sse(
                        "message.completed",
                        {
                            "message_id": str(prepared.text.assistant_message_id),
                            "content": event.completion.content,
                        },
                    )
        except (AppError, OpenAIChatPermanentError) as exc:
            await session.commit()
            code = exc.code if isinstance(exc, AppError) else exc.failure_code
            yield _sse("message.failed", {"error_code": code})
        except Exception:
            await session.commit()
            yield _sse("message.failed", {"error_code": "AI_RESPONSE_FAILED"})

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"
