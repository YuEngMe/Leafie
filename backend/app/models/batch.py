from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.models.enums import (
    BatchItemStatus,
    BatchJobStatus,
    MonthlyReportStatus,
    enum_values,
)


class AIBatchJob(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "ai_batch_jobs"
    __table_args__ = (
        CheckConstraint(f"status IN ({enum_values(BatchJobStatus)})", name="status"),
        CheckConstraint(
            "total_count >= 0 AND completed_count >= 0 AND failed_count >= 0",
            name="counts",
        ),
        CheckConstraint(
            "completed_count + failed_count <= total_count",
            name="completed_counts",
        ),
        Index("ix_ai_batch_jobs_status_created_at", "status", "created_at"),
    )

    job_type: Mapped[str] = mapped_column(String(100), nullable=False)
    provider_batch_id: Mapped[str | None] = mapped_column(String(255), unique=True)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=text("'CREATED'")
    )
    input_file_id: Mapped[str | None] = mapped_column(String(255))
    output_file_id: Mapped[str | None] = mapped_column(String(255))
    total_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    completed_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    failed_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    error_code: Mapped[str | None] = mapped_column(String(100))
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )


class AIBatchItem(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "ai_batch_items"
    __table_args__ = (
        CheckConstraint(f"status IN ({enum_values(BatchItemStatus)})", name="status"),
        CheckConstraint("target_year >= 2000", name="target_year"),
        CheckConstraint("target_month BETWEEN 1 AND 12", name="target_month"),
        Index("ix_ai_batch_items_batch_job_id_status", "batch_job_id", "status"),
    )

    batch_job_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("ai_batch_jobs.id", ondelete="CASCADE"),
        nullable=False,
    )
    custom_id: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="CASCADE"), nullable=False
    )
    target_year: Mapped[int] = mapped_column(Integer, nullable=False)
    target_month: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=text("'PENDING'")
    )
    result: Mapped[dict | None] = mapped_column(JSONB)
    error_code: Mapped[str | None] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class MonthlyReport(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "monthly_reports"
    __table_args__ = (
        CheckConstraint(
            f"status IN ({enum_values(MonthlyReportStatus)})",
            name="status",
        ),
        CheckConstraint("report_year >= 2000", name="report_year"),
        CheckConstraint("report_month BETWEEN 1 AND 12", name="report_month"),
        CheckConstraint(
            "average_condition_score IS NULL OR average_condition_score BETWEEN 0 AND 100",
            name="average_condition_score",
        ),
        UniqueConstraint(
            "plant_id",
            "report_year",
            "report_month",
            name="uq_monthly_reports_plant_year_month",
        ),
        Index(
            "ix_monthly_reports_plant_id_year_month",
            "plant_id",
            text("report_year DESC"),
            text("report_month DESC"),
        ),
    )

    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="CASCADE"), nullable=False
    )
    batch_item_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("ai_batch_items.id", ondelete="SET NULL"), unique=True
    )
    report_year: Mapped[int] = mapped_column(Integer, nullable=False)
    report_month: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=text("'PENDING'")
    )
    average_condition_score: Mapped[int | None] = mapped_column(Integer)
    condition_summary: Mapped[str | None] = mapped_column(Text)
    care_summary: Mapped[str | None] = mapped_column(Text)
    frequent_issues: Mapped[list | None] = mapped_column(JSONB)
    next_month_recommendations: Mapped[list | None] = mapped_column(JSONB)
    model_name: Mapped[str | None] = mapped_column(String(200))
    prompt_version: Mapped[str | None] = mapped_column(String(100))
    generated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
