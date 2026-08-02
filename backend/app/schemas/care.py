from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.enums import CareEventSource, CareEventStatus, CareEventType

OneTimeCareType = Literal[
    CareEventType.FERTILIZING,
    CareEventType.PRUNING,
    CareEventType.CUSTOM,
]


class CareEventCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_event_id: UUID
    type: OneTimeCareType
    title: str = Field(min_length=1, max_length=200)
    due_date: date

    @field_validator("title", mode="before")
    @classmethod
    def strip_title(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class CareEventCompleteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    performed_on: date | None = None


class NextCareEventResponse(BaseModel):
    id: UUID
    due_date: date


class CareEventResponse(BaseModel):
    id: UUID
    plant_id: UUID
    schedule_id: UUID | None
    client_event_id: UUID | None
    type: CareEventType
    title: str | None
    status: CareEventStatus
    source: CareEventSource
    due_date: date
    performed_on: date | None
    recorded_at: datetime | None
    created_at: datetime
    updated_at: datetime


class CareEventCompleteResponse(CareEventResponse):
    next_event: NextCareEventResponse | None


class DailyMemoUpsertRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    content: str = Field(min_length=1, max_length=500)

    @field_validator("content", mode="before")
    @classmethod
    def strip_content(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class DailyMemoResponse(BaseModel):
    id: UUID
    plant_id: UUID
    date: date
    content: str
    created_at: datetime
    updated_at: datetime
