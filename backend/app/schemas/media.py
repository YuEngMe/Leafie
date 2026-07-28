from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import MediaPurpose, MediaStatus


class MediaPresignRequest(BaseModel):
    purpose: MediaPurpose
    file_name: str = Field(min_length=1, max_length=255)
    content_type: Literal["image/jpeg", "image/png", "image/webp"]
    size_bytes: int = Field(gt=0)
    checksum_sha256: str = Field(pattern=r"^[0-9a-fA-F]{64}$")


class MediaPresignResponse(BaseModel):
    media_file_id: UUID
    upload_url: str
    upload_method: Literal["PUT"] = "PUT"
    upload_headers: dict[str, str]
    expires_at: datetime


class MediaCompleteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: MediaStatus
    content_type: str
    size_bytes: int


class MediaDownloadResponse(BaseModel):
    download_url: str
    expires_at: datetime
