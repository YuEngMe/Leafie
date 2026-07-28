from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    get_database_session,
    get_storage_gateway,
)
from app.core.config import settings
from app.core.security import AuthenticatedUser
from app.integrations.storage import StorageGateway
from app.schemas.media import (
    MediaCompleteResponse,
    MediaDownloadResponse,
    MediaPresignRequest,
    MediaPresignResponse,
)
from app.services.media import MediaService, SQLAlchemyMediaRepository

router = APIRouter(prefix="/media", tags=["media"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]
Storage = Annotated[StorageGateway, Depends(get_storage_gateway)]


def build_service(session: AsyncSession, storage: StorageGateway) -> MediaService:
    return MediaService(
        SQLAlchemyMediaRepository(session),
        storage,
        download_url_expires_seconds=settings.media_download_url_expires_seconds,
    )


@router.post(
    "/presign",
    response_model=MediaPresignResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_presigned_upload(
    request: MediaPresignRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> MediaPresignResponse:
    return await build_service(session, storage).create_upload(current_user.id, request)


@router.post("/{media_file_id}/complete", response_model=MediaCompleteResponse)
async def complete_upload(
    media_file_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> MediaCompleteResponse:
    return await build_service(session, storage).complete_upload(
        current_user.id,
        media_file_id,
    )


@router.get("/{media_file_id}/download-url", response_model=MediaDownloadResponse)
async def create_download_url(
    media_file_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> MediaDownloadResponse:
    return await build_service(session, storage).create_download_url(
        current_user.id,
        media_file_id,
    )


@router.delete("/{media_file_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_media(
    media_file_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> Response:
    await build_service(session, storage).soft_delete(current_user.id, media_file_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
