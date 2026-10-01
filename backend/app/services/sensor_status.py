from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from typing import Protocol
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.enums import SensorConnection
from app.models.plant import Plant
from app.models.sensor import PlantSensorDevice, SensorReading
from app.models.user import UserProfile
from app.schemas.sensor import (
    PlantSensorDailyLight,
    PlantSensorLatestReading,
    PlantSensorStatusResponse,
)

# TODO(#118): 임시 보정값. 하드웨어 실측(공기 중 / 물에 담근 raw)으로 교체한다.
SOIL_RAW_DRY = 3200
SOIL_RAW_WET = 1400

# 기기는 10분마다 올린다. 3회 연속 수신이 없으면 STALE로 본다.
SAMPLE_INTERVAL = timedelta(minutes=10)
STALE_AFTER = SAMPLE_INTERVAL * 3

DEFAULT_TIMEZONE = "Asia/Seoul"
# 기기 시계 오차와 큐 지연을 감안해 received_at 범위를 낮 구간보다 넓게 잡는다.
RECEIVED_AT_MARGIN = timedelta(days=1)


def soil_raw_to_percent(soil_raw: int) -> int:
    ratio = (SOIL_RAW_DRY - soil_raw) / (SOIL_RAW_DRY - SOIL_RAW_WET)
    return round(min(max(ratio, 0.0), 1.0) * 100)


@dataclass(frozen=True, slots=True)
class LatestReadingRow:
    lux: Decimal | None
    soil_raw: int | None
    measured_at: datetime | None
    received_at: datetime


class SensorStatusRepository(Protocol):
    async def get_owned_plant_timezone(self, user_id: UUID, plant_id: UUID) -> str | None: ...

    async def get_linked_device_id(self, plant_id: UUID) -> str | None: ...

    async def get_latest_reading(self, device_id: str) -> LatestReadingRow | None: ...

    async def sum_lux(self, device_id: str, start: datetime, end: datetime) -> Decimal: ...


class SQLAlchemySensorStatusRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_owned_plant_timezone(self, user_id: UUID, plant_id: UUID) -> str | None:
        return await self._session.scalar(
            select(UserProfile.timezone)
            .select_from(Plant)
            .join(UserProfile, UserProfile.user_id == Plant.user_id)
            .where(Plant.id == plant_id, Plant.user_id == user_id, Plant.deleted_at.is_(None))
        )

    async def get_linked_device_id(self, plant_id: UUID) -> str | None:
        return await self._session.scalar(
            select(PlantSensorDevice.device_id).where(PlantSensorDevice.plant_id == plant_id)
        )

    async def get_latest_reading(self, device_id: str) -> LatestReadingRow | None:
        row = (
            await self._session.execute(
                select(
                    SensorReading.lux,
                    SensorReading.soil_raw,
                    SensorReading.measured_at,
                    SensorReading.received_at,
                )
                .where(SensorReading.device_id == device_id)
                .order_by(SensorReading.received_at.desc())
                .limit(1)
            )
        ).one_or_none()
        if row is None:
            return None
        return LatestReadingRow(
            lux=row.lux,
            soil_raw=row.soil_raw,
            measured_at=row.measured_at,
            received_at=row.received_at,
        )

    async def sum_lux(self, device_id: str, start: datetime, end: datetime) -> Decimal:
        # measured_at은 null일 수 있어 시각 기준은 COALESCE(measured_at, received_at)다.
        # 이 식은 인덱스를 못 타므로 received_at 범위를 먼저 걸어 후보를 좁힌다.
        measured = func.coalesce(SensorReading.measured_at, SensorReading.received_at)
        total = await self._session.scalar(
            select(func.coalesce(func.sum(SensorReading.lux), 0)).where(
                SensorReading.device_id == device_id,
                SensorReading.received_at >= start - RECEIVED_AT_MARGIN,
                SensorReading.received_at < end + RECEIVED_AT_MARGIN,
                measured >= start,
                measured < end,
            )
        )
        return Decimal(total)


class SensorStatusService:
    def __init__(self, repository: SensorStatusRepository) -> None:
        self._repository = repository

    async def get_owned_status(
        self, user_id: UUID, plant_id: UUID, *, now: datetime | None = None
    ) -> PlantSensorStatusResponse:
        timezone = await self._repository.get_owned_plant_timezone(user_id, plant_id)
        if timezone is None:
            raise AppError(
                code="PLANT_NOT_FOUND", message="식물을 찾을 수 없습니다.", status_code=404
            )
        return await self.get_plant_status(plant_id, timezone, now=now)

    async def get_plant_status(
        self,
        plant_id: UUID,
        timezone: str,
        *,
        day: date | None = None,
        now: datetime | None = None,
    ) -> PlantSensorStatusResponse:
        """소유권 검증 없이 식물의 센서 상태를 집계한다. 호출자가 접근 권한을 확인해야 한다."""
        now = now or datetime.now(UTC)
        zone = _resolve_zone(timezone)
        day = day or now.astimezone(zone).date()

        device_id = await self._repository.get_linked_device_id(plant_id)
        if device_id is None:
            return _empty(plant_id, None, SensorConnection.NO_DEVICE)

        latest = await self._repository.get_latest_reading(device_id)
        if latest is None:
            return _empty(plant_id, device_id, SensorConnection.NO_DATA)

        start = datetime.combine(day, time.min, tzinfo=zone)
        end = datetime.combine(day + timedelta(days=1), time.min, tzinfo=zone)
        lux_sum = await self._repository.sum_lux(device_id, start, end)

        stale = now - latest.received_at > STALE_AFTER
        soil_percent = soil_raw_to_percent(latest.soil_raw) if latest.soil_raw is not None else None
        return PlantSensorStatusResponse(
            plant_id=plant_id,
            device_id=device_id,
            connection=SensorConnection.STALE if stale else SensorConnection.ACTIVE,
            latest=PlantSensorLatestReading(
                lux=float(latest.lux) if latest.lux is not None else None,
                soil_percent=soil_percent,
                measured_at=latest.measured_at,
                received_at=latest.received_at,
            ),
            daily_light=PlantSensorDailyLight(date=day, lux_hours=_lux_hours(lux_sum)),
        )


def _resolve_zone(timezone: str) -> ZoneInfo:
    try:
        return ZoneInfo(timezone)
    except (ZoneInfoNotFoundError, ValueError):
        return ZoneInfo(DEFAULT_TIMEZONE)


def _lux_hours(lux_sum: Decimal) -> float:
    # 샘플 하나가 한 주기(10분) 동안의 조도를 대표한다고 본다. 결측(null)은 합에서 빠진다.
    hours = SAMPLE_INTERVAL.total_seconds() / 3600
    return round(float(lux_sum) * hours, 1)


def _empty(
    plant_id: UUID, device_id: str | None, connection: SensorConnection
) -> PlantSensorStatusResponse:
    return PlantSensorStatusResponse(
        plant_id=plant_id,
        device_id=device_id,
        connection=connection,
        latest=None,
        daily_light=None,
    )
