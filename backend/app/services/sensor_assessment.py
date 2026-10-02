import json
import math
from datetime import UTC, date, datetime, time, timedelta
from statistics import median
from typing import Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, Field, ValidationError, model_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.care import CareEvent
from app.models.enums import SensorConnection
from app.models.plant import Plant, SpeciesCareGuide
from app.models.sensor import PlantSensorDevice, PlantSensorEvent, SensorDevice, SensorReading
from app.models.user import UserProfile
from app.schemas.sensor import SensorAssessment, SensorLevel, SensorMetricAssessment
from app.services.sensor_status import STALE_AFTER, soil_raw_to_percent


class ThresholdRange(BaseModel):
    lower: float = Field(ge=0, allow_inf_nan=False)
    upper: float | None = Field(default=None, ge=0, allow_inf_nan=False)

    @model_validator(mode="after")
    def ordered(self):
        if self.upper is not None and self.upper <= self.lower:
            raise ValueError("Upper threshold must exceed lower threshold")
        return self


class SensorThresholds(BaseModel):
    version: str = Field(min_length=1, max_length=32)
    status: str
    enabled: bool = True
    soil_unit: Literal["relative_percent"]
    light_unit: Literal["lux_hours"]
    soil_percent: ThresholdRange
    light_lux_hours: ThresholdRange

    @model_validator(mode="after")
    def validate_policy(self):
        if self.status not in {"PROVISIONAL", "VALIDATED"}:
            raise ValueError("Unapproved threshold status")
        if self.soil_percent.upper is None or self.soil_percent.upper > 100:
            raise ValueError("Soil thresholds must be a bounded relative percent range")
        return self


def parse_thresholds(profile: dict) -> SensorThresholds | None:
    try:
        policy = SensorThresholds.model_validate(profile.get("sensor_thresholds"))
        return policy if policy.enabled else None
    except (ValidationError, AttributeError):
        return None


def classify(value: float | None, bounds: ThresholdRange) -> SensorLevel:
    if value is None or not math.isfinite(value):
        return SensorLevel.UNKNOWN
    if value < bounds.lower:
        return SensorLevel.LOW
    if bounds.upper is not None and value > bounds.upper:
        return SensorLevel.HIGH
    return SensorLevel.OK


def local_zone(timezone: str) -> ZoneInfo:
    try:
        return ZoneInfo(timezone)
    except (ValueError, ZoneInfoNotFoundError):
        return ZoneInfo("Asia/Seoul")


def day_window(day: date, timezone: str) -> tuple[datetime, datetime]:
    zone = local_zone(timezone)
    return (
        datetime.combine(day, time.min, zone).astimezone(UTC),
        datetime.combine(day + timedelta(days=1), time.min, zone).astimezone(UTC),
    )


class SensorAssessmentService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def read(
        self, plant_id: UUID, *, day: date | None = None, now: datetime | None = None
    ) -> SensorAssessment:
        now = now or datetime.now(UTC)
        context = (
            await self.session.execute(
                select(
                    Plant, SpeciesCareGuide, UserProfile.timezone, PlantSensorDevice, SensorDevice
                )
                .join(
                    SpeciesCareGuide,
                    SpeciesCareGuide.species_reference_id == Plant.species_reference_id,
                )
                .join(UserProfile, UserProfile.user_id == Plant.user_id)
                .outerjoin(PlantSensorDevice, PlantSensorDevice.plant_id == Plant.id)
                .outerjoin(SensorDevice, SensorDevice.id == PlantSensorDevice.device_id)
                .where(
                    Plant.id == plant_id,
                    Plant.deleted_at.is_(None),
                    UserProfile.deleted_at.is_(None),
                    UserProfile.deletion_status.is_(None),
                )
            )
        ).one_or_none()
        result = SensorAssessment(
            connection=SensorConnection.NO_DEVICE,
            soil=SensorMetricAssessment(unit="relative_percent", reason="NO_DEVICE"),
            light=SensorMetricAssessment(unit="lux_hours", reason="NO_DEVICE"),
        )
        if context is None:
            return result
        plant, guide, timezone, link, device = context
        thresholds = parse_thresholds(guide.care_profile)
        if thresholds:
            result.threshold_version = thresholds.version
            # Soil conversion still uses the temporary shared calibration (#118).
            result.provisional = True
            result.soil.lower, result.soil.upper = (
                thresholds.soil_percent.lower,
                thresholds.soil_percent.upper,
            )
            result.light.lower, result.light.upper = (
                thresholds.light_lux_hours.lower,
                thresholds.light_lux_hours.upper,
            )
        if link is None or device.owner_user_id != plant.user_id or device.status != "CLAIMED":
            return result
        # Evaluate light against a completed local day, not an unfinished morning.
        today = now.astimezone(local_zone(timezone)).date()
        light_day = day if day is not None else today - timedelta(days=1)
        start, end = day_window(light_day, timezone)
        end_of_soil = min(end, now) if day is not None else now
        measured = func.coalesce(SensorReading.measured_at, SensorReading.received_at)
        recent = list(
            await self.session.scalars(
                select(SensorReading)
                .where(
                    SensorReading.device_id == device.id,
                    SensorReading.received_at >= max(link.created_at, end_of_soil - STALE_AFTER),
                    SensorReading.received_at <= end_of_soil,
                    measured >= max(link.created_at, end_of_soil - STALE_AFTER),
                    measured <= end_of_soil,
                )
                .order_by(measured.desc(), SensorReading.received_at.desc())
                .limit(12)
            )
        )
        result.connection = SensorConnection.ACTIVE if recent else SensorConnection.STALE
        result.soil.reason = "NO_RECENT_DATA"
        result.light.date = light_day
        result.light.reason = "NO_RECENT_DATA"
        if not recent:
            history = await self.session.scalar(
                select(SensorReading.id)
                .where(
                    SensorReading.device_id == device.id,
                    SensorReading.received_at >= link.created_at,
                    SensorReading.received_at <= end_of_soil,
                    measured >= link.created_at,
                    measured <= end_of_soil,
                )
                .limit(1)
            )
            if history is None:
                result.connection = SensorConnection.NO_DATA
                result.soil.reason = result.light.reason = "NO_DATA"
            return result
        if thresholds is None:
            result.soil.reason = result.light.reason = "THRESHOLDS_UNAVAILABLE"
            return result

        soil_buckets = {}
        for reading in recent:
            timestamp = reading.measured_at or reading.received_at
            if reading.soil_raw is not None:
                soil_buckets.setdefault(int(timestamp.timestamp()) // 600, reading.soil_raw)
        result.soil.sample_count = len(soil_buckets)
        result.soil.reason = "INSUFFICIENT_SAMPLES"
        if len(soil_buckets) >= 3:
            result.soil.value = soil_raw_to_percent(round(median(list(soil_buckets.values())[:3])))
            result.soil.state = classify(result.soil.value, thresholds.soil_percent)
            result.soil.reason = None

        # Collapse repeated deliveries in each ten-minute bucket before integrating.
        rows = list(
            await self.session.scalars(
                select(SensorReading)
                .where(
                    SensorReading.device_id == device.id,
                    SensorReading.received_at >= max(link.created_at, start - timedelta(days=1)),
                    SensorReading.received_at <= min(now, end + timedelta(days=1)),
                    measured >= max(link.created_at, start),
                    measured < min(end, now),
                    SensorReading.lux.is_not(None),
                )
                .order_by(SensorReading.received_at.desc())
            )
        )
        light_buckets = {}
        for reading in rows:
            timestamp = reading.measured_at or reading.received_at
            light_buckets.setdefault(int(timestamp.timestamp()) // 600, float(reading.lux))
        expected = max(1, round((end - start).total_seconds() / 600))
        result.light.sample_count = len(light_buckets)
        result.light.coverage_ratio = min(1, round(len(light_buckets) / expected, 3))
        result.light.value = round(sum(light_buckets.values()) / 6, 1) if rows else None
        if end > now:
            result.light.reason = "DAY_IN_PROGRESS"
        elif result.light.coverage_ratio < 0.8:
            result.light.reason = "INSUFFICIENT_COVERAGE"
        else:
            result.light.state = classify(result.light.value, thresholds.light_lux_hours)
            result.light.reason = None
        return result


class SQLAlchemyLetterSensorSummary:
    def __init__(self, database):
        self.database = database

    async def read(self, plant_id: UUID, diary_date: date) -> str:
        async with self.database.session_context() as session:
            assessment = await SensorAssessmentService(session).read(plant_id, day=diary_date)
            timezone = await session.scalar(
                select(UserProfile.timezone)
                .join(Plant, Plant.user_id == UserProfile.user_id)
                .where(Plant.id == plant_id)
            )
            start, end = day_window(diary_date, timezone or "Asia/Seoul")
            requests = list(
                await session.scalars(
                    select(PlantSensorEvent)
                    .where(
                        PlantSensorEvent.plant_id == plant_id,
                        PlantSensorEvent.type == "SOIL_LOW",
                        PlantSensorEvent.occurred_at >= start,
                        PlantSensorEvent.occurred_at < end,
                    )
                    .order_by(PlantSensorEvent.occurred_at)
                )
            )
            completions = list(
                await session.scalars(
                    select(CareEvent.recorded_at).where(
                        CareEvent.plant_id == plant_id,
                        CareEvent.type == "WATERING",
                        CareEvent.status == "COMPLETED",
                        CareEvent.performed_on == diary_date,
                    )
                )
            )
            return json.dumps(
                {
                    "diaryDate": diary_date.isoformat(),
                    "sensor": assessment.model_dump(mode="json", by_alias=True),
                    "waterRequests": [
                        {
                            "requestedAt": request.occurred_at.isoformat(),
                            "wateringRecordedAfterRequest": any(
                                t >= request.occurred_at for t in completions
                            ),
                        }
                        for request in requests[-10:]
                    ],
                    "waterRequestCount": len(requests),
                    "wateringRecordedCount": len(completions),
                    "interpretation": "초기 기준은 추정값. UNKNOWN은 정상/부족으로 단정하지 말 것. "
                    "급수 기록 시각은 실제 급수 시각을 보장하지 않음. 광량은 해당 날짜 관측분이며 "
                    "DAY_IN_PROGRESS는 최종 하루 판정이 아님. "
                    "없는 물 요구/급수 사실을 만들지 말 것.",
                },
                ensure_ascii=False,
            )
