from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.enums import DevicePlatform


class NotificationResponse(BaseModel):
    id: UUID
    plant_id: UUID | None
    type: str
    title: str
    body: str
    source_type: str | None
    source_id: UUID | None
    read_at: datetime | None
    created_at: datetime


class NotificationListResponse(BaseModel):
    items: list[NotificationResponse]
    next_cursor: str | None
    has_next: bool


class DeviceRegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    platform: DevicePlatform
    installation_id: str = Field(min_length=1, max_length=4096)

    @field_validator("installation_id", mode="before")
    @classmethod
    def strip_installation_id(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class DeviceResponse(BaseModel):
    id: UUID
    platform: DevicePlatform
    created_at: datetime
