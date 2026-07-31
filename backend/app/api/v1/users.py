from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    get_database_session,
    get_job_queue,
)
from app.core.config import settings
from app.core.request_context import create_request_id, get_request_id
from app.core.security import AuthenticatedUser
from app.integrations.queue import JobQueue
from app.schemas.queue import JobType, QueueJob
from app.schemas.user import (
    AccountDeleteRequest,
    PushNotificationResponse,
    PushNotificationUpdate,
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
Queue = Annotated[JobQueue, Depends(get_job_queue)]


def build_service(session: AsyncSession) -> UserService:
    return UserService(
        SQLAlchemyUserRepository(session),
        reauth_max_age_seconds=settings.account_deletion_reauth_max_age_seconds,
    )


@router.get("/me", response_model=UserProfileResponse)
async def get_me(
    current_user: CurrentUser,
    session: DatabaseSession,
) -> UserProfileResponse:
    return await build_service(session).get_me(current_user.id)


@router.patch("/me", response_model=UserProfileResponse)
async def update_me(
    request: UserProfileUpdate,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> UserProfileResponse:
    return await build_service(session).update_me(current_user.id, request)


@router.patch("/me/selected-plant", response_model=SelectedPlantResponse)
async def update_selected_plant(
    request: SelectedPlantUpdate,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> SelectedPlantResponse:
    return await build_service(session).update_selected_plant(
        current_user.id,
        request.selected_plant_id,
    )


@router.get("/me/stats", response_model=UserStatsResponse)
async def get_stats(
    current_user: CurrentUser,
    session: DatabaseSession,
) -> UserStatsResponse:
    return await build_service(session).get_stats(current_user.id)


@router.patch("/me/notification-settings", response_model=PushNotificationResponse)
async def update_notification_settings(
    request: PushNotificationUpdate,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> PushNotificationResponse:
    return await build_service(session).update_push_enabled(
        current_user.id,
        request.push_enabled,
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(
    _request: AccountDeleteRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    queue: Queue,
) -> Response:
    newly_scheduled = await build_service(session).request_account_deletion(
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
