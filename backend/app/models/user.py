from datetime import datetime
from uuid import UUID

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, String, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.models.enums import AccountDeletionStatus, DevicePlatform, enum_values


class UserProfile(Base, TimestampMixin):
    __tablename__ = "user_profiles"
    __table_args__ = (
        CheckConstraint(
            "(deleted_at IS NULL AND deletion_status IS NULL) OR "
            f"(deleted_at IS NOT NULL AND deletion_status IN "
            f"({enum_values(AccountDeletionStatus)}))",
            name="deletion_state",
        ),
        Index("ix_user_profiles_selected_plant_id", "selected_plant_id"),
        Index("ix_user_profiles_deletion_status", "deletion_status"),
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("auth.users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    nickname: Mapped[str] = mapped_column(String(100), nullable=False)
    timezone: Mapped[str] = mapped_column(
        String(64), nullable=False, server_default=text("'Asia/Seoul'")
    )
    selected_plant_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("plants.id", ondelete="SET NULL", use_alter=True),
    )
    push_enabled: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    profile_completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    deletion_status: Mapped[str | None] = mapped_column(String(16))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class DeviceToken(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "device_tokens"
    __table_args__ = (
        CheckConstraint(
            f"platform IN ({enum_values(DevicePlatform)})",
            name="platform",
        ),
        Index("ix_device_tokens_user_id_revoked_at", "user_id", "revoked_at"),
        Index(
            "uq_device_tokens_active_token",
            "token",
            unique=True,
            postgresql_where=text("revoked_at IS NULL"),
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False
    )
    platform: Mapped[str] = mapped_column(String(16), nullable=False)
    token: Mapped[str] = mapped_column(String(4096), nullable=False)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
