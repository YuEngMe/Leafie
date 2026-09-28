from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_database_session
from app.core.security import AuthenticatedUser
from app.schemas.sensor import SensorDeviceRegisterRequest, SensorDeviceResponse
from app.services.sensor import SensorDeviceService, SQLAlchemySensorDeviceRepository

router = APIRouter(prefix="/sensor-devices", tags=["sensor-devices"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]


def build_service(session: AsyncSession) -> SensorDeviceService:
    return SensorDeviceService(SQLAlchemySensorDeviceRepository(session))


@router.post(
    "",
    response_model=SensorDeviceResponse,
    responses={status.HTTP_201_CREATED: {"model": SensorDeviceResponse}},
)
async def register_sensor_device(
    request: SensorDeviceRegisterRequest,
    response: Response,
    _current_user: CurrentUser,
    session: DatabaseSession,
) -> SensorDeviceResponse:
    result = await build_service(session).register_device(request.device_id)
    response.status_code = status.HTTP_201_CREATED if result.created else status.HTTP_200_OK
    return result.response
