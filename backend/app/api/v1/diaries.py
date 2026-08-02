from datetime import date as Date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    get_database_session,
    get_job_queue,
    get_storage_gateway,
)
from app.core.config import settings
from app.core.request_context import create_request_id, get_request_id
from app.core.security import AuthenticatedUser
from app.integrations.queue import JobQueue
from app.integrations.storage import StorageGateway
from app.schemas.diary import DiaryMonthResponse, DiaryResponse, DiaryUpsertRequest
from app.schemas.queue import JobType, QueueJob
from app.services.diary import DiaryService, SQLAlchemyDiaryRepository

router = APIRouter(prefix="/plants/{plant_id}/diaries", tags=["diaries"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]
Storage = Annotated[StorageGateway, Depends(get_storage_gateway)]
Queue = Annotated[JobQueue, Depends(get_job_queue)]


def build_service(session: AsyncSession, storage: StorageGateway) -> DiaryService:
    return DiaryService(
        SQLAlchemyDiaryRepository(session),
        storage,
        download_url_expires_seconds=settings.media_download_url_expires_seconds,
    )


@router.get("", response_model=DiaryMonthResponse)
async def list_diaries(
    plant_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
    year: Annotated[int, Query(ge=1, le=9998)],
    month: Annotated[int, Query(ge=1, le=12)],
) -> DiaryMonthResponse:
    return await build_service(session, storage).list_month(
        current_user.id,
        plant_id,
        year,
        month,
    )


@router.put(
    "/{date}",
    response_model=DiaryResponse,
    responses={status.HTTP_201_CREATED: {"model": DiaryResponse}},
)
async def upsert_diary(
    plant_id: UUID,
    date: Date,
    request: DiaryUpsertRequest,
    response: Response,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
    queue: Queue,
) -> DiaryResponse:
    result = await build_service(session, storage).upsert_diary(
        current_user.id,
        plant_id,
        date,
        request,
    )
    await enqueue_media_cleanup(result.cleanup_media_ids, session, queue)
    response.status_code = status.HTTP_201_CREATED if result.created else status.HTTP_200_OK
    return result.response


@router.get("/{date}", response_model=DiaryResponse)
async def get_diary(
    plant_id: UUID,
    date: Date,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> DiaryResponse:
    return await build_service(session, storage).get_diary(
        current_user.id,
        plant_id,
        date,
    )


@router.delete("/{date}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_diary(
    plant_id: UUID,
    date: Date,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
    queue: Queue,
) -> Response:
    result = await build_service(session, storage).delete_diary(
        current_user.id,
        plant_id,
        date,
    )
    await enqueue_media_cleanup(result.cleanup_media_ids, session, queue)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


async def enqueue_media_cleanup(
    media_file_ids: tuple[UUID, ...],
    session: AsyncSession,
    queue: JobQueue,
) -> None:
    trace_id = get_request_id() or create_request_id()
    for media_file_id in media_file_ids:
        await queue.enqueue(
            QueueJob(
                job_type=JobType.STORAGE_OBJECT_DELETE,
                resource_id=media_file_id,
                trace_id=trace_id,
            ),
            session=session,
        )
