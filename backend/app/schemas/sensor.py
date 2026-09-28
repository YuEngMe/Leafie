from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import SensorDeviceClaimStatus, SensorDeviceStatus

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
