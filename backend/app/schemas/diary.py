from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.enums import DiaryWeather


class DiaryUpsertRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    weather: DiaryWeather
    title: str = Field(min_length=1, max_length=100)
    content: str = Field(min_length=1, max_length=2000)
    media_file_id: UUID | None = None

    @field_validator("title", "content", mode="before")
    @classmethod
    def strip_nonblank_text(cls, value: object) -> object:
        if not isinstance(value, str):
            return value
        stripped = value.strip()
        if not stripped:
            raise ValueError("공백만 입력할 수 없습니다.")
        return stripped


class DiaryMediaResponse(BaseModel):
    id: UUID
    download_url: str
    expires_at: datetime


class DiaryResponse(BaseModel):
    id: UUID
    plant_id: UUID
    diary_date: date
    weather: DiaryWeather | None
    title: str | None
    content: str
    media: DiaryMediaResponse | None
    created_at: datetime
    updated_at: datetime


class DiaryMonthEntry(BaseModel):
    id: UUID
    diary_date: date
    weather: DiaryWeather | None
    title: str | None
    has_photo: bool


class DiaryMonthResponse(BaseModel):
    entries: list[DiaryMonthEntry]
