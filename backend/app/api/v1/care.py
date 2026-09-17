from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_database_session
from app.core.security import AuthenticatedUser
from app.schemas.care import (
    CareEventCompleteRequest,
    CareEventCompleteResponse,
    CareEventCreateRequest,
    CareEventResponse,
)
from app.services.care import CareService, SQLAlchemyCareRepository

router = APIRouter(tags=["care"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]


def build_service(session: AsyncSession) -> CareService:
    return CareService(SQLAlchemyCareRepository(session))


@router.post(
    "/plants/{plant_id}/care-events",
    response_model=CareEventResponse,
    responses={status.HTTP_201_CREATED: {"model": CareEventResponse}},
)
async def create_care_event(
    plant_id: UUID,
    request: CareEventCreateRequest,
    response: Response,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> CareEventResponse:
    result = await build_service(session).create_event(
        current_user.id, plant_id, request
    )
    response.status_code = status.HTTP_201_CREATED if result.created else status.HTTP_200_OK
    assert isinstance(result.response, CareEventResponse)
    return result.response


@router.post(
    "/care-events/{event_id}/complete",
    response_model=CareEventCompleteResponse,
)
async def complete_care_event(
    event_id: UUID,
    request: CareEventCompleteRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> CareEventCompleteResponse:
    return await build_service(session).complete_event(current_user.id, event_id, request)
