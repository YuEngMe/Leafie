from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_database_session
from app.core.security import AuthenticatedUser
from app.schemas.sensor import (
    SensorDeviceClaimCompleteRequest,
    SensorDeviceClaimCompleteResponse,
    SensorDeviceClaimCreateResponse,
    SensorDeviceClaimStatusResponse,
    SensorDeviceRegisterRequest,
    SensorDeviceResponse,
)
from app.services.sensor import (
    SensorDeviceClaimService,
    SensorDeviceService,
    SQLAlchemySensorDeviceClaimRepository,
    SQLAlchemySensorDeviceRepository,
)

router = APIRouter(prefix="/sensor-devices", tags=["sensor-devices"])
claims_router = APIRouter(prefix="/sensor-device-claims", tags=["sensor-devices"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]


def build_service(session: AsyncSession) -> SensorDeviceService:
    return SensorDeviceService(SQLAlchemySensorDeviceRepository(session))


def build_claim_service(session: AsyncSession) -> SensorDeviceClaimService:
    return SensorDeviceClaimService(SQLAlchemySensorDeviceClaimRepository(session))


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


@router.post(
    "/{device_id}/claims",
    response_model=SensorDeviceClaimCreateResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_sensor_device_claim(
    device_id: str,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> SensorDeviceClaimCreateResponse:
    return await build_claim_service(session).create_claim(current_user.id, device_id)


@claims_router.post(
    "/{claim_token}/complete",
    response_model=SensorDeviceClaimCompleteResponse,
)
async def complete_sensor_device_claim(
    claim_token: str,
    request: SensorDeviceClaimCompleteRequest,
    session: DatabaseSession,
) -> SensorDeviceClaimCompleteResponse:
    return await build_claim_service(session).complete_claim(claim_token, request.device_id)


@claims_router.get(
    "/{claim_token}",
    response_model=SensorDeviceClaimStatusResponse,
)
async def get_sensor_device_claim_status(
    claim_token: str,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> SensorDeviceClaimStatusResponse:
    return await build_claim_service(session).get_status(current_user.id, claim_token)
