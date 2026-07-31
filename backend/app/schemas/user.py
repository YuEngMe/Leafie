from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class UserProfileResponse(BaseModel):
    user_id: UUID
    email: str
    email_verified_at: datetime
    auth_providers: list[str]
    can_change_password: bool
    nickname: str
    timezone: str
    selected_plant_id: UUID | None
    push_enabled: bool
    profile_completed: bool
    profile_completed_at: datetime | None
    gardener_days: int = Field(ge=0)


class UserProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nickname: str = Field(min_length=1, max_length=100)

    @field_validator("nickname", mode="before")
    @classmethod
    def strip_text(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @model_validator(mode="after")
    def reject_blank_nickname(self) -> "UserProfileUpdate":
        if not self.nickname:
            raise ValueError("nickname은 비어 있을 수 없습니다.")
        return self


class PushNotificationUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    push_enabled: bool


class PushNotificationResponse(BaseModel):
    push_enabled: bool


class SelectedPlantUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    selected_plant_id: UUID | None


class SelectedPlantResponse(BaseModel):
    selected_plant_id: UUID | None


class AccountDeleteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    confirmation: Literal["DELETE"]


class UserStatsResponse(BaseModel):
    plant_count: int = Field(ge=0)
    diary_count: int = Field(ge=0)
    diagnosis_count: int = Field(ge=0)
