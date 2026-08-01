from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, UUIDPrimaryKeyMixin
from app.models.enums import DiagnosisCondition, DiagnosisStatus, enum_values


class Diagnosis(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "diagnoses"
    __table_args__ = (
        CheckConstraint(f"status IN ({enum_values(DiagnosisStatus)})", name="status"),
        CheckConstraint(
            "overall_condition IS NULL OR "
            f"overall_condition IN ({enum_values(DiagnosisCondition)})",
            name="overall_condition",
        ),
        CheckConstraint(
            "possible_causes IS NULL OR "
            "(jsonb_typeof(possible_causes) = 'array' AND "
            "jsonb_array_length(possible_causes) <= 3)",
            name="possible_causes",
        ),
        CheckConstraint(
            "latency_ms IS NULL OR latency_ms >= 0",
            name="latency_ms",
        ),
        CheckConstraint("estimated_cost IS NULL OR estimated_cost >= 0", name="estimated_cost"),
        UniqueConstraint("media_file_id", name="uq_diagnoses_media_file_id"),
        Index("ix_diagnoses_plant_id_created_at", "plant_id", text("created_at DESC")),
        Index("ix_diagnoses_status_created_at", "status", "created_at"),
    )

    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="CASCADE"), nullable=False
    )
    related_conversation_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("ai_conversations.id", ondelete="SET NULL", use_alter=True),
    )
    media_file_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("media_files.id", ondelete="RESTRICT"),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=text("'PENDING'")
    )
    overall_condition: Mapped[str | None] = mapped_column(String(16))
    input_context_snapshot: Mapped[dict | None] = mapped_column(JSONB)
    image_quality_result: Mapped[dict | None] = mapped_column(JSONB)
    condition_label: Mapped[str | None] = mapped_column(String(200))
    observations: Mapped[list | None] = mapped_column(JSONB)
    possible_causes: Mapped[list | None] = mapped_column(JSONB)
    recommended_care: Mapped[list | None] = mapped_column(JSONB)
    retake_reason_code: Mapped[str | None] = mapped_column(String(100))
    failure_code: Mapped[str | None] = mapped_column(String(100))
    diagnosis_provider: Mapped[str | None] = mapped_column(String(100))
    diagnosis_model_name: Mapped[str | None] = mapped_column(String(200))
    provider_response_id: Mapped[str | None] = mapped_column(String(255))
    explanation_model_name: Mapped[str | None] = mapped_column(String(200))
    explanation_prompt_version: Mapped[str | None] = mapped_column(String(100))
    care_rule_version: Mapped[str | None] = mapped_column(String(100))
    latency_ms: Mapped[int | None] = mapped_column(Integer)
    estimated_cost: Mapped[Decimal | None] = mapped_column(Numeric(12, 6))
    cost_currency: Mapped[str | None] = mapped_column(String(3))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
