from datetime import date as Date
from datetime import datetime
from enum import StrEnum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import SensorConnection, SensorDeviceClaimStatus, SensorDeviceStatus

DEVICE_ID_PATTERN = r"^[0-9A-F]{12}$"


class SensorDeviceRegisterRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    device_id: str = Field(alias="deviceId", pattern=DEVICE_ID_PATTERN)


class SensorDeviceResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    device_id: str = Field(alias="deviceId")
    status: SensorDeviceStatus


class SensorDeviceClaimCreateResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    claim_token: str = Field(alias="claimToken")


class SensorDeviceClaimCompleteRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    device_id: str = Field(alias="deviceId", pattern=DEVICE_ID_PATTERN)


class SensorDeviceClaimCompleteResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    device_token: str = Field(alias="deviceToken")


class SensorDeviceClaimStatusResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    status: SensorDeviceClaimStatus


class SensorDeviceListItemResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    device_id: str = Field(alias="deviceId")
    status: SensorDeviceStatus
    last_seen_at: datetime | None = Field(alias="lastSeenAt")
    plant_id: UUID | None = Field(alias="plantId")
    lux: float | None = None
    soil_percent: int | None = Field(alias="soilPercent")
    measured_at: datetime | None = Field(alias="measuredAt")


class SensorDeviceListResponse(BaseModel):
    items: list[SensorDeviceListItemResponse]


class PlantSensorDeviceConnectRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    device_id: str = Field(alias="deviceId", pattern=DEVICE_ID_PATTERN)


class PlantSensorDeviceResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    plant_id: UUID = Field(alias="plantId")
    device_id: str = Field(alias="deviceId")


class PlantSensorLatestReading(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    lux: float | None
    soil_percent: int | None = Field(alias="soilPercent")
    measured_at: datetime | None = Field(alias="measuredAt")
    received_at: datetime = Field(alias="receivedAt")


class PlantSensorDailyLight(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    date: Date
    lux_hours: float = Field(alias="luxHours")


class PlantSensorStatusResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    plant_id: UUID = Field(alias="plantId")
    device_id: str | None = Field(alias="deviceId")
    connection: SensorConnection
    latest: PlantSensorLatestReading | None
    daily_light: PlantSensorDailyLight | None = Field(alias="dailyLight")
    assessment: "SensorAssessment | None" = None


class SensorLevel(StrEnum):
    UNKNOWN = "UNKNOWN"
    LOW = "LOW"
    OK = "OK"
    HIGH = "HIGH"


class SensorMetricAssessment(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    state: SensorLevel = SensorLevel.UNKNOWN
    value: float | None = None
    unit: str
    lower: float | None = None
    upper: float | None = None
    reason: str | None = None
    date: Date | None = None
    sample_count: int = Field(default=0, alias="sampleCount")
    coverage_ratio: float | None = Field(default=None, alias="coverageRatio")


class SensorAssessment(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    connection: SensorConnection
    threshold_version: str | None = Field(default=None, alias="thresholdVersion")
    provisional: bool = True
    soil: SensorMetricAssessment
    light: SensorMetricAssessment
