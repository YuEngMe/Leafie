from datetime import date, datetime
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.models.enums import (
    CareEventSource,
    CareEventStatus,
    CareEventType,
    CareScheduleType,
    WaterRecommendationSource,
    enum_values,
)


class CareSchedule(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "care_schedules"
    __table_args__ = (
        CheckConstraint(f"type IN ({enum_values(CareScheduleType)})", name="type"),
        CheckConstraint("interval_days > 0", name="interval_days"),
        CheckConstraint(
            "(recommended_water_min_ml IS NULL AND recommended_water_max_ml IS NULL) OR "
            "(type = 'WATERING' AND recommended_water_min_ml > 0 AND "
            "recommended_water_min_ml <= recommended_water_max_ml)",
            name="water_amount_range",
        ),
        CheckConstraint(
            "recommendation_source IS NULL OR "
            f"recommendation_source IN ({enum_values(WaterRecommendationSource)})",
            name="recommendation_source",
        ),
        UniqueConstraint("plant_id", "type", name="uq_care_schedules_plant_type"),
        Index("ix_care_schedules_enabled_next_due_date", "enabled", "next_due_date"),
    )

    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="CASCADE"), nullable=False
    )
    type: Mapped[str] = mapped_column(String(16), nullable=False)
    interval_days: Mapped[int] = mapped_column(Integer, nullable=False)
    next_due_date: Mapped[date] = mapped_column(Date, nullable=False)
    recommended_water_min_ml: Mapped[int | None] = mapped_column(Integer)
    recommended_water_max_ml: Mapped[int | None] = mapped_column(Integer)
    recommendation_source: Mapped[str | None] = mapped_column(String(32))
    enabled: Mapped[bool] = mapped_column(nullable=False, server_default=text("true"))


class CareEvent(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "care_events"
    __table_args__ = (
        CheckConstraint(f"type IN ({enum_values(CareEventType)})", name="type"),
        CheckConstraint(f"status IN ({enum_values(CareEventStatus)})", name="status"),
        CheckConstraint(f"source IN ({enum_values(CareEventSource)})", name="source"),
        CheckConstraint(
            "(status = 'COMPLETED' AND performed_on IS NOT NULL AND recorded_at IS NOT NULL) OR "
            "(status <> 'COMPLETED' AND performed_on IS NULL AND recorded_at IS NULL)",
            name="completion_fields",
        ),
        CheckConstraint(
            "type <> 'CUSTOM' OR (title IS NOT NULL AND schedule_id IS NULL)",
            name="custom_event",
        ),
        Index("ix_care_events_plant_id_due_date", "plant_id", "due_date"),
        Index("ix_care_events_plant_id_performed_on", "plant_id", "performed_on"),
        Index("ix_care_events_status_due_date", "status", "due_date"),
    )

    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="CASCADE"), nullable=False
    )
    schedule_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("care_schedules.id", ondelete="SET NULL")
    )
    source_diagnosis_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("diagnoses.id", ondelete="SET NULL", use_alter=True),
    )
    type: Mapped[str] = mapped_column(String(16), nullable=False)
    title: Mapped[str | None] = mapped_column(String(200))
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=text("'SCHEDULED'")
    )
    source: Mapped[str] = mapped_column(String(24), nullable=False)
    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    performed_on: Mapped[date | None] = mapped_column(Date)
    recorded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
