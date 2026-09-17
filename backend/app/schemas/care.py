from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.enums import CareEventSource, CareEventStatus, CareEventType

CreatableCareType = Literal[
    CareEventType.REPOTTING,
    CareEventType.FERTILIZING,
]


class CareEventCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_event_id: UUID
    care_type: CreatableCareType
    due_date: date


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
    care_type: CareEventType
    status: CareEventStatus
    source: CareEventSource
    due_date: date
    performed_on: date | None
    recorded_at: datetime | None
    created_at: datetime
    updated_at: datetime


class CareEventCompleteResponse(CareEventResponse):
    next_event: NextCareEventResponse | None
