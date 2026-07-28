from pydantic import BaseModel, Field


class CursorPage[T](BaseModel):
    items: list[T]
    next_cursor: str | None = None
    has_next: bool = False


class CursorParams(BaseModel):
    cursor: str | None = None
    limit: int = Field(default=20, ge=1, le=100)


class HealthResponse(BaseModel):
    status: str
