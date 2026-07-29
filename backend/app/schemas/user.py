from datetime import datetime
from typing import Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class UserProfileResponse(BaseModel):
    user_id: UUID
    email: str
    email_verified_at: datetime
    auth_providers: list[str]
    can_change_password: bool
    nickname: str
    bio: str | None
    profile_media_file_id: UUID | None
    profile_image_url: str | None
    timezone: str
    selected_plant_id: UUID | None
    gardener_days: int = Field(ge=0)


class UserProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nickname: str | None = Field(default=None, min_length=1, max_length=100)
    bio: str | None = Field(default=None, max_length=500)
    profile_media_file_id: UUID | None = None
    timezone: str | None = Field(default=None, min_length=1, max_length=64)

    @field_validator("nickname", "bio", mode="before")
    @classmethod
    def strip_text(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value

    @field_validator("timezone")
    @classmethod
    def validate_timezone(cls, value: str | None) -> str | None:
        if value is None:
            return value
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("유효한 IANA 시간대를 입력해 주세요.") from exc
        return value

    @model_validator(mode="after")
    def reject_null_required_fields(self) -> "UserProfileUpdate":
        for field_name in ("nickname", "timezone"):
            if field_name in self.model_fields_set and getattr(self, field_name) is None:
                raise ValueError(f"{field_name}은(는) null일 수 없습니다.")
        return self


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
