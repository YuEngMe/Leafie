from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_database_session
from app.core.security import AuthenticatedUser
from app.schemas.plant import PlantCreateRequest, PlantCreateResponse
from app.services.plant import PlantRegistrationService, SQLAlchemyPlantRegistrationRepository

router = APIRouter(prefix="/plants", tags=["plants"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]


def build_service(session: AsyncSession) -> PlantRegistrationService:
    return PlantRegistrationService(SQLAlchemyPlantRegistrationRepository(session))


@router.post("", response_model=PlantCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_plant(
    request: PlantCreateRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> PlantCreateResponse:
    return await build_service(session).create_plant(current_user.id, request)
