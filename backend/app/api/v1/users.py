from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
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
from app.schemas.queue import JobType, QueueJob
from app.schemas.user import (
    AccountDeleteRequest,
    SelectedPlantResponse,
    SelectedPlantUpdate,
    UserProfileResponse,
    UserProfileUpdate,
    UserStatsResponse,
)
from app.services.user import SQLAlchemyUserRepository, UserService

router = APIRouter(prefix="/users", tags=["users"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]
Storage = Annotated[StorageGateway, Depends(get_storage_gateway)]
Queue = Annotated[JobQueue, Depends(get_job_queue)]


def build_service(session: AsyncSession, storage: StorageGateway) -> UserService:
    return UserService(
        SQLAlchemyUserRepository(session),
        storage,
        profile_url_expires_seconds=settings.media_download_url_expires_seconds,
        reauth_max_age_seconds=settings.account_deletion_reauth_max_age_seconds,
    )


@router.get("/me", response_model=UserProfileResponse)
async def get_me(
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> UserProfileResponse:
    return await build_service(session, storage).get_me(current_user.id)


@router.patch("/me", response_model=UserProfileResponse)
async def update_me(
    request: UserProfileUpdate,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> UserProfileResponse:
    return await build_service(session, storage).update_me(current_user.id, request)


@router.patch("/me/selected-plant", response_model=SelectedPlantResponse)
async def update_selected_plant(
    request: SelectedPlantUpdate,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> SelectedPlantResponse:
    return await build_service(session, storage).update_selected_plant(
        current_user.id,
        request.selected_plant_id,
    )


@router.get("/me/stats", response_model=UserStatsResponse)
async def get_stats(
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> UserStatsResponse:
    return await build_service(session, storage).get_stats(current_user.id)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(
    _request: AccountDeleteRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
    queue: Queue,
) -> Response:
    newly_scheduled = await build_service(session, storage).request_account_deletion(
        current_user.id,
        current_user.claims,
    )
    if newly_scheduled:
        await queue.enqueue(
            QueueJob(
                job_type=JobType.ACCOUNT_DELETE,
                resource_id=current_user.id,
                trace_id=get_request_id() or create_request_id(),
            ),
            session=session,
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
