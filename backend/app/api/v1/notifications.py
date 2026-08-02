from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_database_session
from app.core.security import AuthenticatedUser
from app.schemas.notification import (
    DeviceRegisterRequest,
    DeviceResponse,
    NotificationListResponse,
    NotificationResponse,
)
from app.services.notification import NotificationService, SQLAlchemyNotificationRepository

router = APIRouter(tags=["notifications"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]


def build_service(session: AsyncSession) -> NotificationService:
    return NotificationService(SQLAlchemyNotificationRepository(session))


@router.get("/notifications", response_model=NotificationListResponse)
async def list_notifications(
    current_user: CurrentUser,
    session: DatabaseSession,
    cursor: Annotated[str | None, Query()] = None,
    unread_only: Annotated[bool, Query()] = False,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> NotificationListResponse:
    return await build_service(session).list(current_user.id, cursor, limit, unread_only)


@router.post(
    "/notifications/{notification_id}/read",
    response_model=NotificationResponse,
)
async def mark_notification_read(
    notification_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> NotificationResponse:
    return await build_service(session).mark_read(current_user.id, notification_id)


@router.post("/notifications/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_notifications_read(
    current_user: CurrentUser,
    session: DatabaseSession,
) -> Response:
    await build_service(session).mark_all_read(current_user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/devices", response_model=DeviceResponse)
async def register_device(
    request: DeviceRegisterRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> DeviceResponse:
    return await build_service(session).register_device(current_user.id, request)


@router.delete("/devices/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_device(
    device_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> Response:
    await build_service(session).revoke_device(current_user.id, device_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
