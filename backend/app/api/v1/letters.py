from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_database_session
from app.core.security import AuthenticatedUser
from app.schemas.letter import LetterDetail, LetterListResponse, LetterUnreadCount
from app.services.letter import LetterService

router = APIRouter(prefix="/letters", tags=["letters"])
Session = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]


@router.get("", response_model=LetterListResponse)
async def list_letters(
    session: Session,
    current_user: CurrentUser,
    plant_id: UUID | None = None,
    unread_only: bool = False,
    cursor: Annotated[str | None, Query(max_length=512)] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> LetterListResponse:
    return await LetterService(session).list(
        current_user.id, plant_id=plant_id, unread_only=unread_only, cursor=cursor, limit=limit
    )


@router.get("/unread-count", response_model=LetterUnreadCount)
async def unread_count(
    session: Session,
    current_user: CurrentUser,
    plant_id: UUID | None = None,
) -> LetterUnreadCount:
    return LetterUnreadCount(
        unread_count=await LetterService(session).unread_count(current_user.id, plant_id)
    )


@router.get("/{letter_id}", response_model=LetterDetail)
async def detail(letter_id: UUID, session: Session, current_user: CurrentUser) -> LetterDetail:
    return await LetterService(session).detail(current_user.id, letter_id)


@router.post("/{letter_id}/read", response_model=LetterDetail)
async def read(letter_id: UUID, session: Session, current_user: CurrentUser) -> LetterDetail:
    return await LetterService(session).detail(current_user.id, letter_id, mark_read=True)


@router.delete("/{letter_id}", status_code=204)
async def delete(letter_id: UUID, session: Session, current_user: CurrentUser) -> Response:
    await LetterService(session).delete(current_user.id, letter_id)
    return Response(status_code=204)
