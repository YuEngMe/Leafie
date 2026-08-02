from enum import StrEnum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class JobType(StrEnum):
    CARE_NOTIFICATION_COLLECT = "CARE_NOTIFICATION_COLLECT"
    SPECIES_IDENTIFICATION_RUN = "SPECIES_IDENTIFICATION_RUN"
    DIAGNOSIS_RUN = "DIAGNOSIS_RUN"
    CHAT_IMAGE_ANALYSIS = "CHAT_IMAGE_ANALYSIS"
    PUSH_NOTIFICATION_SEND = "PUSH_NOTIFICATION_SEND"
    STORAGE_OBJECT_DELETE = "STORAGE_OBJECT_DELETE"
    ACCOUNT_DELETE = "ACCOUNT_DELETE"


class QueueJob(BaseModel):
    model_config = ConfigDict(extra="forbid")

    job_type: JobType
    resource_id: UUID
    attempt: int = Field(default=0, ge=0)
    trace_id: str = Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9._:-]+$")
