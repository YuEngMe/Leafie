from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Protocol
from uuid import UUID

from sqlalchemy import delete, or_, select, true, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.enums import SensorDeviceStatus
from app.models.plant import Plant
from app.models.sensor import PlantSensorDevice, SensorDevice, SensorReading
from app.schemas.sensor import (
    PlantSensorDeviceResponse,
    SensorDeviceListItemResponse,
    SensorDeviceListResponse,
)


@dataclass(frozen=True, slots=True)
class SensorDeviceListRow:
    device: SensorDevice
    plant_id: UUID | None
    lux: Decimal | None
    soil_raw: int | None
    measured_at: datetime | None


class SensorDeviceManagementRepository(Protocol):
    async def list_devices(self, user_id: UUID) -> list[SensorDeviceListRow]: ...

    async def get_owned_device(self, user_id: UUID, device_id: str) -> SensorDevice | None: ...

    async def get_owned_plant(self, user_id: UUID, plant_id: UUID) -> Plant | None: ...

    async def remove_existing_links(self, *, plant_id: UUID, device_id: str) -> None: ...

    async def add_link(self, link: PlantSensorDevice) -> None: ...

    async def delete_link_for_plant(self, plant_id: UUID) -> None: ...

    async def release_device(self, device: SensorDevice) -> None: ...

    async def flush(self) -> None: ...


class SQLAlchemySensorDeviceManagementRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_devices(self, user_id: UUID) -> list[SensorDeviceListRow]:
        latest_reading = (
            select(
                SensorReading.lux.label("lux"),
                SensorReading.soil_raw.label("soil_raw"),
                SensorReading.measured_at.label("measured_at"),
            )
            .where(SensorReading.device_id == SensorDevice.id)
            .order_by(SensorReading.received_at.desc())
            .limit(1)
            .correlate(SensorDevice)
            .lateral("latest_reading")
        )
        statement = (
            select(
                SensorDevice,
                PlantSensorDevice.plant_id,
                latest_reading.c.lux,
                latest_reading.c.soil_raw,
                latest_reading.c.measured_at,
            )
            .outerjoin(PlantSensorDevice, PlantSensorDevice.device_id == SensorDevice.id)
            .outerjoin(latest_reading, true())
            .where(SensorDevice.owner_user_id == user_id)
            .order_by(SensorDevice.claimed_at)
        )
        rows = await self._session.execute(statement)
        return [
            SensorDeviceListRow(
                device=row[0],
                plant_id=row.plant_id,
                lux=row.lux,
                soil_raw=row.soil_raw,
                measured_at=row.measured_at,
            )
            for row in rows
        ]

    async def get_owned_device(self, user_id: UUID, device_id: str) -> SensorDevice | None:
        return await self._session.scalar(
            select(SensorDevice).where(
                SensorDevice.id == device_id, SensorDevice.owner_user_id == user_id
            )
        )

    async def get_owned_plant(self, user_id: UUID, plant_id: UUID) -> Plant | None:
        return await self._session.scalar(
            select(Plant).where(
                Plant.id == plant_id, Plant.user_id == user_id, Plant.deleted_at.is_(None)
            )
        )

    async def remove_existing_links(self, *, plant_id: UUID, device_id: str) -> None:
        await self._session.execute(
            delete(PlantSensorDevice).where(
                or_(
                    PlantSensorDevice.plant_id == plant_id,
                    PlantSensorDevice.device_id == device_id,
                )
            )
        )
        await self._session.flush()

    async def add_link(self, link: PlantSensorDevice) -> None:
        try:
            async with self._session.begin_nested():
                self._session.add(link)
                await self._session.flush()
        except IntegrityError as error:
            raise AppError(
                code="SENSOR_DEVICE_PLANT_LINK_CONFLICT",
                message="연결이 겹쳤습니다. 다시 시도해 주세요.",
                status_code=409,
            ) from error

    async def delete_link_for_plant(self, plant_id: UUID) -> None:
        await self._session.execute(
            delete(PlantSensorDevice).where(PlantSensorDevice.plant_id == plant_id)
        )

    async def release_device(self, device: SensorDevice) -> None:
        await self._session.execute(
            delete(PlantSensorDevice).where(PlantSensorDevice.device_id == device.id)
        )
        await self._session.execute(
            update(SensorDevice)
            .where(SensorDevice.id == device.id)
            .values(
                status=SensorDeviceStatus.UNCLAIMED.value,
                owner_user_id=None,
                sensor_token_hash=None,
                claimed_at=None,
            )
        )

    async def flush(self) -> None:
        await self._session.flush()


class SensorDeviceManagementService:
    def __init__(self, repository: SensorDeviceManagementRepository) -> None:
        self._repository = repository

    async def list_devices(self, user_id: UUID) -> SensorDeviceListResponse:
        rows = await self._repository.list_devices(user_id)
        return SensorDeviceListResponse(
            items=[
                SensorDeviceListItemResponse(
                    device_id=row.device.id,
                    status=SensorDeviceStatus(row.device.status),
                    last_seen_at=row.device.last_seen_at,
                    plant_id=row.plant_id,
                    lux=row.lux,
                    soil_raw=row.soil_raw,
                    measured_at=row.measured_at,
                )
                for row in rows
            ]
        )

    async def connect_plant_device(
        self, user_id: UUID, plant_id: UUID, device_id: str
    ) -> PlantSensorDeviceResponse:
        plant = await self._repository.get_owned_plant(user_id, plant_id)
        if plant is None:
            raise AppError(
                code="PLANT_NOT_FOUND", message="식물을 찾을 수 없습니다.", status_code=404
            )
        device = await self._repository.get_owned_device(user_id, device_id)
        if device is None:
            raise AppError(
                code="SENSOR_DEVICE_NOT_FOUND", message="기기를 찾을 수 없습니다.", status_code=404
            )

        # 식물 하나에 기기 하나, 기기 하나에 식물 하나: 기존 연결이 있으면 자동으로 교체한다.
        await self._repository.remove_existing_links(plant_id=plant_id, device_id=device_id)
        await self._repository.add_link(PlantSensorDevice(plant_id=plant_id, device_id=device_id))
        return PlantSensorDeviceResponse(plant_id=plant_id, device_id=device_id)

    async def disconnect_plant_device(self, user_id: UUID, plant_id: UUID) -> None:
        plant = await self._repository.get_owned_plant(user_id, plant_id)
        if plant is None:
            raise AppError(
                code="PLANT_NOT_FOUND", message="식물을 찾을 수 없습니다.", status_code=404
            )
        await self._repository.delete_link_for_plant(plant_id)
        await self._repository.flush()

    async def release_device(self, user_id: UUID, device_id: str) -> None:
        device = await self._repository.get_owned_device(user_id, device_id)
        if device is None:
            raise AppError(
                code="SENSOR_DEVICE_NOT_FOUND", message="기기를 찾을 수 없습니다.", status_code=404
            )
        await self._repository.release_device(device)
        await self._repository.flush()
