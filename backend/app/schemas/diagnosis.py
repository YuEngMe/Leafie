from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import DiagnosisCondition, DiagnosisStatus


class DiagnosisCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    conversation_id: UUID
    media_file_id: UUID


class DiagnosisCreatedResponse(BaseModel):
    diagnosis_id: UUID
    status: DiagnosisStatus
    created_at: datetime


class DiagnosisCauseResponse(BaseModel):
    name: str
    confidence: float | None = Field(default=None, ge=0, le=1)


class DiagnosisListItem(BaseModel):
    id: UUID
    status: DiagnosisStatus
    diagnosed_at: datetime
    photo_url: str
    condition_label: str | None
    retake_reason_code: str | None
    failure_code: str | None


class DiagnosisListResponse(BaseModel):
    items: list[DiagnosisListItem]
    has_next: bool
    next_cursor: str | None


class DiagnosisDetailResponse(BaseModel):
    id: UUID
    plant_id: UUID
    status: DiagnosisStatus
    diagnosed_at: datetime
    photo_url: str
    overall_condition: DiagnosisCondition | None
    condition_label: str | None
    observations: list[str]
    possible_causes: list[DiagnosisCauseResponse]
    recommended_care: list[str]
    retake_reason_code: str | None
    failure_code: str | None
    related_conversation_id: UUID | None


class DiagnosisStatusResponse(BaseModel):
    diagnosis_id: UUID
    status: DiagnosisStatus
