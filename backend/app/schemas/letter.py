from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel


class LetterListItem(BaseModel):
    id: UUID
    plant_id: UUID
    plant_nickname: str
    diary_id: UUID
    diary_date: date
    status: Literal["COMPLETED"] = "COMPLETED"
    preview: str
    generated_at: datetime
    published_at: datetime
    is_read: bool


class LetterDetail(LetterListItem):
    content: str
    read_at: datetime | None


class LetterListResponse(BaseModel):
    items: list[LetterListItem]
    next_cursor: str | None


class LetterUnreadCount(BaseModel):
    unread_count: int
