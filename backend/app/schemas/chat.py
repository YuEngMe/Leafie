from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.enums import AIActionStatus, AIMessageStatus, ChatRole


class ConversationCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(default="새 채팅", min_length=1, max_length=200)


class ConversationResponse(BaseModel):
    id: UUID
    plant_id: UUID
    title: str
    last_message_at: datetime | None
    created_at: datetime


class ConversationListResponse(BaseModel):
    items: list[ConversationResponse]
    has_next: bool
    next_cursor: str | None


class MessageCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_message_id: UUID
    content: str = Field(default="", max_length=4000)
    media_file_id: UUID | None = None

    @model_validator(mode="after")
    def require_content_or_media(self) -> "MessageCreateRequest":
        self.content = self.content.strip()
        if not self.content and self.media_file_id is None:
            raise ValueError("내용이나 사진 중 하나는 필요합니다.")
        return self


class AIActionResponse(BaseModel):
    id: UUID
    plant_id: UUID
    action_type: str
    payload: dict
    status: AIActionStatus
    expires_at: datetime | None
    confirmed_at: datetime | None
    executed_at: datetime | None
    created_at: datetime


class MessageResponse(BaseModel):
    id: UUID
    client_message_id: UUID | None
    conversation_id: UUID
    related_diagnosis_id: UUID | None
    media_file_id: UUID | None
    role: ChatRole
    status: AIMessageStatus
    content: str
    provider: str | None
    model_name: str | None
    created_at: datetime
    actions: list[AIActionResponse] = Field(default_factory=list)


class MessageListResponse(BaseModel):
    items: list[MessageResponse]
    has_next: bool
    next_cursor: str | None


class MessageAcceptedResponse(BaseModel):
    message_id: UUID
    status: AIMessageStatus
