from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

ConditionScore = Literal[0, 25, 50, 75, 100]


class DiaryUpsertRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    content: str = Field(min_length=1, max_length=2000)
    condition_score: ConditionScore
    media_file_id: UUID | None = None

    @field_validator("condition_score", mode="before")
    @classmethod
    def require_integer_condition_score(cls, value: object) -> object:
        if type(value) is not int:
            raise ValueError("컨디션 점수는 정수여야 합니다.")
        return value

    @field_validator("content", mode="before")
    @classmethod
    def strip_nonblank_content(cls, value: object) -> object:
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
    content: str
    condition_score: ConditionScore
    condition_level: int = Field(ge=1, le=5)
    media: DiaryMediaResponse | None
    created_at: datetime
    updated_at: datetime


class DiaryMonthEntry(BaseModel):
    id: UUID
    diary_date: date
    condition_score: ConditionScore
    condition_level: int = Field(ge=1, le=5)
    has_photo: bool


class DiaryMonthStatistics(BaseModel):
    entry_count: int = Field(ge=0)
    average_score: int | None = Field(default=None, ge=0, le=100)
    average_level: int | None = Field(default=None, ge=1, le=5)


class DiaryMonthResponse(BaseModel):
    entries: list[DiaryMonthEntry]
    statistics: DiaryMonthStatistics
