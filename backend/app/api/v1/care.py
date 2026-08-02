from datetime import date as Date
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
    DailyMemoResponse,
    DailyMemoUpsertRequest,
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
    result = await build_service(session).create_one_time_event(
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


@router.put(
    "/plants/{plant_id}/daily-memos/{date}",
    response_model=DailyMemoResponse,
    responses={status.HTTP_201_CREATED: {"model": DailyMemoResponse}},
)
async def upsert_daily_memo(
    plant_id: UUID,
    date: Date,
    request: DailyMemoUpsertRequest,
    response: Response,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> DailyMemoResponse:
    result = await build_service(session).upsert_daily_memo(
        current_user.id, plant_id, date, request
    )
    response.status_code = status.HTTP_201_CREATED if result.created else status.HTTP_200_OK
    assert isinstance(result.response, DailyMemoResponse)
    return result.response


@router.delete(
    "/plants/{plant_id}/daily-memos/{date}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_daily_memo(
    plant_id: UUID,
    date: Date,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> Response:
    await build_service(session).delete_daily_memo(current_user.id, plant_id, date)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
