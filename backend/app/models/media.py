from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, UUIDPrimaryKeyMixin
from app.models.enums import (
    MediaPurpose,
    MediaStatus,
    SpeciesIdentificationStatus,
    enum_values,
)


class MediaFile(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "media_files"
    __table_args__ = (
        CheckConstraint(f"purpose IN ({enum_values(MediaPurpose)})", name="purpose"),
        CheckConstraint(f"status IN ({enum_values(MediaStatus)})", name="status"),
        CheckConstraint("size_bytes IS NULL OR size_bytes >= 0", name="size_bytes"),
        CheckConstraint("width IS NULL OR width > 0", name="width"),
        CheckConstraint("height IS NULL OR height > 0", name="height"),
        Index("ix_media_files_user_id_status_created_at", "user_id", "status", "created_at"),
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False
    )
    purpose: Mapped[str] = mapped_column(String(32), nullable=False)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=text("'PENDING'")
    )
    bucket_name: Mapped[str] = mapped_column(String(100), nullable=False)
    object_path: Mapped[str] = mapped_column(String(1024), nullable=False, unique=True)
    content_type: Mapped[str] = mapped_column(String(100), nullable=False)
    size_bytes: Mapped[int | None] = mapped_column(BigInteger)
    checksum_sha256: Mapped[str | None] = mapped_column(String(64))
    width: Mapped[int | None] = mapped_column(Integer)
    height: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class SpeciesIdentification(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "species_identifications"
    __table_args__ = (
        CheckConstraint(
            f"status IN ({enum_values(SpeciesIdentificationStatus)})",
            name="status",
        ),
        UniqueConstraint("media_file_id", name="uq_species_identifications_media_file_id"),
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False
    )
    media_file_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("media_files.id", ondelete="RESTRICT"), nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=text("'PENDING'")
    )
    provider: Mapped[str | None] = mapped_column(String(100))
    candidates: Mapped[list | None] = mapped_column(JSONB)
    failure_code: Mapped[str | None] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
