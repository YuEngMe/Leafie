from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Index, String, Text, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, UUIDPrimaryKeyMixin


class Notification(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "notifications"
    __table_args__ = (
        Index(
            "ix_notifications_user_id_read_at_created_at",
            "user_id",
            "read_at",
            text("created_at DESC"),
        ),
        Index(
            "uq_notifications_source",
            "user_id",
            "type",
            "source_type",
            "source_id",
            unique=True,
            postgresql_where=text("source_id IS NOT NULL"),
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False
    )
    plant_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="CASCADE")
    )
    type: Mapped[str] = mapped_column(String(100), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    source_type: Mapped[str | None] = mapped_column(String(100))
    source_id: Mapped[UUID | None] = mapped_column(PG_UUID(as_uuid=True))
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
