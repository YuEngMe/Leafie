from datetime import date, datetime
from uuid import UUID

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
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

from app.db.base import Base, SoftDeleteMixin, TimestampMixin, UUIDPrimaryKeyMixin
from app.models.enums import (
    PersonalityType,
    Placement,
    PlantCategory,
    PotType,
    SpeciesSelectionMethod,
    enum_values,
)


class SpeciesCareGuide(Base):
    __tablename__ = "species_care_guides"
    __table_args__ = (
        CheckConstraint(f"category IN ({enum_values(PlantCategory)})", name="category"),
        CheckConstraint(
            "(recommended_water_min_ml IS NULL AND recommended_water_max_ml IS NULL) OR "
            "(recommended_water_min_ml > 0 AND "
            "recommended_water_min_ml <= recommended_water_max_ml)",
            name="water_amount_range",
        ),
        CheckConstraint(
            "default_watering_interval_days IS NULL OR default_watering_interval_days > 0",
            name="default_watering_interval_days",
        ),
        CheckConstraint(
            "default_repotting_interval_days IS NULL OR default_repotting_interval_days > 0",
            name="default_repotting_interval_days",
        ),
        Index("ix_species_care_guides_display_name", "display_name"),
        Index("ix_species_care_guides_gbif_id", "gbif_id", unique=True),
        Index(
            "ix_species_care_guides_plantnet_species_id",
            "plantnet_species_id",
            unique=True,
            postgresql_where=text("plantnet_species_id IS NOT NULL"),
        ),
    )

    species_reference_id: Mapped[str] = mapped_column(String(255), primary_key=True)
    display_name: Mapped[str] = mapped_column(String(200), nullable=False)
    scientific_name: Mapped[str | None] = mapped_column(String(255))
    plantnet_species_id: Mapped[str | None] = mapped_column(String(255))
    gbif_id: Mapped[int | None] = mapped_column(BigInteger)
    aliases: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, default=list, server_default=text("'[]'::jsonb")
    )
    family_name: Mapped[str | None] = mapped_column(String(100))
    flowering_period: Mapped[str | None] = mapped_column(String(100))
    category: Mapped[str] = mapped_column(String(32), nullable=False)
    recommended_water_min_ml: Mapped[int | None] = mapped_column(Integer)
    recommended_water_max_ml: Mapped[int | None] = mapped_column(Integer)
    default_watering_interval_days: Mapped[int | None] = mapped_column(Integer)
    default_repotting_interval_days: Mapped[int | None] = mapped_column(Integer)
    care_profile: Mapped[dict] = mapped_column(
        JSONB, nullable=False, default=dict, server_default=text("'{}'::jsonb")
    )
    diagnosis_profile: Mapped[dict] = mapped_column(
        JSONB, nullable=False, default=dict, server_default=text("'{}'::jsonb")
    )
    source_references: Mapped[list[dict]] = mapped_column(
        JSONB, nullable=False, default=list, server_default=text("'[]'::jsonb")
    )
    data_version: Mapped[str | None] = mapped_column(String(32))
    reviewed_at: Mapped[date | None] = mapped_column(Date)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )


class Plant(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "plants"
    __table_args__ = (
        CheckConstraint(
            f"species_selection_method IN ({enum_values(SpeciesSelectionMethod)})",
            name="species_selection_method",
        ),
        CheckConstraint(
            f"pot_type IN ({enum_values(PotType)})",
            name="pot_type",
        ),
        CheckConstraint(
            f"placement IN ({enum_values(Placement)})",
            name="placement",
        ),
        CheckConstraint(
            f"personality_type IN ({enum_values(PersonalityType)})",
            name="personality_type",
        ),
        CheckConstraint(
            "char_length(registration_request_hash) = 64",
            name="registration_request_hash_length",
        ),
        UniqueConstraint(
            "user_id",
            "client_registration_id",
            name="uq_plants_user_client_registration_id",
        ),
        Index("ix_plants_user_id_deleted_at", "user_id", "deleted_at"),
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False
    )
    client_registration_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    registration_request_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    species_reference_id: Mapped[str] = mapped_column(
        String(255),
        ForeignKey("species_care_guides.species_reference_id", ondelete="RESTRICT"),
        nullable=False,
    )
    species_identification_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("species_identifications.id", ondelete="SET NULL"),
        unique=True,
    )
    primary_media_file_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("media_files.id", ondelete="SET NULL")
    )
    nickname: Mapped[str] = mapped_column(String(100), nullable=False)
    species_selection_method: Mapped[str] = mapped_column(String(16), nullable=False)
    started_on: Mapped[date] = mapped_column(Date, nullable=False)
    place_name: Mapped[str] = mapped_column(String(100), nullable=False)
    pot_type: Mapped[str] = mapped_column(String(32), nullable=False)
    placement: Mapped[str] = mapped_column(String(32), nullable=False)
    personality_type: Mapped[str] = mapped_column(String(32), nullable=False)
    color_id: Mapped[str] = mapped_column(String(100), nullable=False)
    hair_id: Mapped[str] = mapped_column(String(100), nullable=False)
    accessory_id: Mapped[str] = mapped_column(String(100), nullable=False)


class PlantDailyMemo(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "plant_daily_memos"
    __table_args__ = (
        UniqueConstraint("plant_id", "memo_date", name="uq_plant_daily_memos_plant_date"),
    )

    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="CASCADE"), nullable=False
    )
    memo_date: Mapped[date] = mapped_column(Date, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)


class PlantDiary(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "plant_diaries"
    __table_args__ = (
        CheckConstraint(
            "char_length(btrim(content)) BETWEEN 1 AND 2000",
            name="content_length",
        ),
        CheckConstraint(
            "condition_score IN (0, 25, 50, 75, 100)",
            name="condition_score",
        ),
        UniqueConstraint("media_file_id", name="uq_plant_diaries_media_file_id"),
        UniqueConstraint("plant_id", "diary_date", name="uq_plant_diaries_plant_date"),
    )

    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="CASCADE"), nullable=False
    )
    media_file_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("media_files.id", ondelete="SET NULL")
    )
    diary_date: Mapped[date] = mapped_column(Date, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    condition_score: Mapped[int] = mapped_column(Integer, nullable=False)
