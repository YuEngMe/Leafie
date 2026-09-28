from dataclasses import dataclass
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import SensorDeviceStatus
from app.models.sensor import SensorDevice
from app.schemas.sensor import SensorDeviceResponse


@dataclass(frozen=True, slots=True)
class SensorDeviceRegistrationResult:
    response: SensorDeviceResponse
    created: bool


class SensorDeviceRepository(Protocol):
    async def get(self, device_id: str) -> SensorDevice | None: ...

    async def add(self, device: SensorDevice) -> tuple[SensorDevice, bool]: ...


class SQLAlchemySensorDeviceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, device_id: str) -> SensorDevice | None:
        return await self._session.scalar(select(SensorDevice).where(SensorDevice.id == device_id))

    async def add(self, device: SensorDevice) -> tuple[SensorDevice, bool]:
        try:
            async with self._session.begin_nested():
                self._session.add(device)
                await self._session.flush()
            return device, True
        except IntegrityError:
            existing = await self._session.scalar(
                select(SensorDevice).where(SensorDevice.id == device.id)
            )
            if existing is None:
                raise
            return existing, False


class SensorDeviceService:
    def __init__(self, repository: SensorDeviceRepository) -> None:
        self._repository = repository

    async def register_device(self, device_id: str) -> SensorDeviceRegistrationResult:
        existing = await self._repository.get(device_id)
        if existing is not None:
            return SensorDeviceRegistrationResult(response=_to_response(existing), created=False)

        device = SensorDevice(id=device_id, status=SensorDeviceStatus.UNCLAIMED.value)
        stored, created = await self._repository.add(device)
        return SensorDeviceRegistrationResult(response=_to_response(stored), created=created)


def _to_response(device: SensorDevice) -> SensorDeviceResponse:
    return SensorDeviceResponse(device_id=device.id, status=SensorDeviceStatus(device.status))
