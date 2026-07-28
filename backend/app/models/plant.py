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
    ConditionLevel,
    PersonalityType,
    PlantCategory,
    SpeciesSelectionMethod,
    TaxonRank,
    WaterRecommendationSource,
    enum_values,
)


class SpeciesCareGuide(Base):
    __tablename__ = "species_care_guides"
    __table_args__ = (
        CheckConstraint(f"category IN ({enum_values(PlantCategory)})", name="category"),
        CheckConstraint(
            f"water_recommendation_source IN ({enum_values(WaterRecommendationSource)})",
            name="water_recommendation_source",
        ),
        CheckConstraint(f"taxon_rank IN ({enum_values(TaxonRank)})", name="taxon_rank"),
        CheckConstraint(
            "(recommended_water_min_ml IS NULL AND recommended_water_max_ml IS NULL) OR "
            "(recommended_water_min_ml > 0 AND "
            "recommended_water_min_ml <= recommended_water_max_ml)",
            name="water_amount_range",
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
    powo_id: Mapped[str | None] = mapped_column(String(100))
    aliases: Mapped[list[str]] = mapped_column(
        JSONB, nullable=False, default=list, server_default=text("'[]'::jsonb")
    )
    taxon_rank: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=text("'SPECIES'")
    )
    genus: Mapped[str | None] = mapped_column(String(100))
    family: Mapped[str | None] = mapped_column(String(100))
    category: Mapped[str] = mapped_column(String(32), nullable=False)
    recommended_water_min_ml: Mapped[int | None] = mapped_column(Integer)
    recommended_water_max_ml: Mapped[int | None] = mapped_column(Integer)
    water_recommendation_source: Mapped[str] = mapped_column(
        String(32), nullable=False, server_default=text("'SPECIES_GUIDE'")
    )
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )


class Plant(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "plants"
    __table_args__ = (
        CheckConstraint(f"category IN ({enum_values(PlantCategory)})", name="category"),
        CheckConstraint(
            f"species_selection_method IN ({enum_values(SpeciesSelectionMethod)})",
            name="species_selection_method",
        ),
        Index("ix_plants_user_id_deleted_at", "user_id", "deleted_at"),
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False
    )
    primary_media_file_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("media_files.id", ondelete="SET NULL")
    )
    species_identification_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("species_identifications.id", ondelete="SET NULL"),
        unique=True,
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    category: Mapped[str] = mapped_column(String(32), nullable=False)
    species_name: Mapped[str] = mapped_column(String(200), nullable=False)
    species_scientific_name: Mapped[str | None] = mapped_column(String(255))
    species_reference_id: Mapped[str] = mapped_column(String(255), nullable=False)
    species_selection_method: Mapped[str] = mapped_column(String(16), nullable=False)
    started_on: Mapped[date] = mapped_column(Date, nullable=False)
    memo: Mapped[str | None] = mapped_column(Text)


class PlantCharacter(Base):
    __tablename__ = "plant_characters"
    __table_args__ = (
        CheckConstraint(
            f"personality_type IN ({enum_values(PersonalityType)})",
            name="personality_type",
        ),
    )

    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("plants.id", ondelete="CASCADE"),
        primary_key=True,
    )
    base_type: Mapped[str] = mapped_column(String(100), nullable=False)
    body_color: Mapped[str] = mapped_column(String(100), nullable=False)
    head_item: Mapped[str | None] = mapped_column(String(100))
    accessory: Mapped[str | None] = mapped_column(String(100))
    personality_type: Mapped[str] = mapped_column(String(32), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )


class PlantEnvironment(Base):
    __tablename__ = "plant_environments"

    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("plants.id", ondelete="CASCADE"),
        primary_key=True,
    )
    place_name: Mapped[str] = mapped_column(String(100), nullable=False)
    pot_type: Mapped[str | None] = mapped_column(String(100))
    placement: Mapped[str | None] = mapped_column(String(100))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )


class PlantDiary(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "plant_diaries"
    __table_args__ = (
        CheckConstraint(
            f"condition_level IN ({enum_values(ConditionLevel)})",
            name="condition_level",
        ),
        CheckConstraint(
            "(condition_level = 'VERY_BAD' AND condition_score = 10) OR "
            "(condition_level = 'BAD' AND condition_score = 30) OR "
            "(condition_level = 'NORMAL' AND condition_score = 50) OR "
            "(condition_level = 'GOOD' AND condition_score = 70) OR "
            "(condition_level = 'VERY_GOOD' AND condition_score = 90)",
            name="condition_score_mapping",
        ),
        UniqueConstraint("plant_id", "diary_date", name="uq_plant_diaries_plant_date"),
        Index("ix_plant_diaries_plant_id_diary_date", "plant_id", text("diary_date DESC")),
    )

    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="CASCADE"), nullable=False
    )
    media_file_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("media_files.id", ondelete="SET NULL")
    )
    diary_date: Mapped[date] = mapped_column(Date, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    condition_level: Mapped[str] = mapped_column(String(16), nullable=False)
    condition_score: Mapped[int] = mapped_column(Integer, nullable=False)
