"""align final MVP schema

Revision ID: a8f31c2d9e40
Revises: 4c2d9f7a6b10
Create Date: 2026-07-31 22:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "a8f31c2d9e40"
down_revision: str | Sequence[str] | None = "4c2d9f7a6b10"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    _update_user_profiles()
    _update_species_guides()
    _update_plants()
    _update_diaries_and_memos()
    _update_care()
    _update_diagnoses()
    _update_chat()
    _drop_deferred_features()


def _update_user_profiles() -> None:
    op.drop_constraint(
        op.f("fk_user_profiles_profile_media_file_id_media_files"),
        "user_profiles",
        type_="foreignkey",
    )
    op.drop_column("user_profiles", "profile_media_file_id")
    op.drop_column("user_profiles", "bio")
    op.add_column(
        "user_profiles",
        sa.Column("push_enabled", sa.Boolean(), server_default=sa.text("true"), nullable=False),
    )
    op.add_column(
        "user_profiles",
        sa.Column("profile_completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "user_profiles",
        sa.Column("deletion_failure_code", sa.String(length=100), nullable=True),
    )
    op.drop_constraint(op.f("ck_media_files_purpose"), "media_files", type_="check")
    op.create_check_constraint(
        op.f("ck_media_files_purpose"),
        "media_files",
        "purpose IN ('PLANT_PROFILE', 'SPECIES_IDENTIFICATION', 'DIARY', 'DIAGNOSIS', 'CHAT')",
    )


def _update_species_guides() -> None:
    op.drop_constraint(
        op.f("ck_species_care_guides_water_recommendation_source"),
        "species_care_guides",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_species_care_guides_taxon_rank"),
        "species_care_guides",
        type_="check",
    )
    op.alter_column("species_care_guides", "family", new_column_name="family_name")
    op.alter_column(
        "species_care_guides", "care_data_version", new_column_name="data_version"
    )
    op.alter_column(
        "species_care_guides", "care_data_reviewed_at", new_column_name="reviewed_at"
    )
    op.add_column(
        "species_care_guides",
        sa.Column("flowering_period", sa.String(length=100), nullable=True),
    )
    op.drop_column("species_care_guides", "powo_id")
    op.drop_column("species_care_guides", "taxon_rank")
    op.drop_column("species_care_guides", "genus")
    op.drop_column("species_care_guides", "water_recommendation_source")


def _update_plants() -> None:
    op.drop_constraint(op.f("ck_plants_category"), "plants", type_="check")
    op.alter_column("plants", "name", new_column_name="nickname")
    for column in (
        sa.Column("place_name", sa.String(length=100), nullable=True),
        sa.Column("pot_type", sa.String(length=32), nullable=True),
        sa.Column("placement", sa.String(length=32), nullable=True),
        sa.Column("personality_type", sa.String(length=32), nullable=True),
        sa.Column("color_id", sa.String(length=100), nullable=True),
        sa.Column("hair_id", sa.String(length=100), nullable=True),
        sa.Column("accessory_id", sa.String(length=100), nullable=True),
    ):
        op.add_column("plants", column)

    op.execute(
        """
        UPDATE plants AS p
        SET personality_type = c.personality_type,
            color_id = c.body_color,
            hair_id = COALESCE(c.head_item, 'NONE'),
            accessory_id = COALESCE(c.accessory, 'NONE')
        FROM plant_characters AS c
        WHERE c.plant_id = p.id
        """
    )
    op.execute(
        """
        UPDATE plants AS p
        SET place_name = e.place_name,
            pot_type = COALESCE(e.pot_type, 'OTHER'),
            placement = COALESCE(e.placement, 'OTHER')
        FROM plant_environments AS e
        WHERE e.plant_id = p.id
        """
    )
    op.execute(
        """
        UPDATE plants
        SET place_name = COALESCE(place_name, '기타'),
            pot_type = COALESCE(pot_type, 'OTHER'),
            placement = COALESCE(placement, 'OTHER'),
            personality_type = COALESCE(personality_type, 'OUTGOING'),
            color_id = COALESCE(color_id, 'DEFAULT'),
            hair_id = COALESCE(hair_id, 'NONE'),
            accessory_id = COALESCE(accessory_id, 'NONE')
        """
    )
    for name in (
        "place_name",
        "pot_type",
        "placement",
        "personality_type",
        "color_id",
        "hair_id",
        "accessory_id",
    ):
        op.alter_column("plants", name, nullable=False)

    op.create_check_constraint(
        op.f("ck_plants_pot_type"),
        "plants",
        "pot_type IN ('TERRACOTTA', 'PLASTIC', 'GLASS', 'CERAMIC', 'HYDROPONIC', 'OTHER')",
    )
    op.create_check_constraint(
        op.f("ck_plants_placement"),
        "plants",
        "placement IN ('VERANDA', 'WINDOW', 'LIVING_ROOM', 'BEDROOM', 'DESK', 'OTHER')",
    )
    op.create_check_constraint(
        op.f("ck_plants_personality_type"),
        "plants",
        "personality_type IN ('OUTGOING', 'CHIC', 'CUTE', 'CRUSH', 'INTROVERTED', 'CHUNGCHEONG')",
    )
    op.create_foreign_key(
        "fk_plants_species_reference_id_species_care_guides",
        "plants",
        "species_care_guides",
        ["species_reference_id"],
        ["species_reference_id"],
        ondelete="RESTRICT",
    )
    op.drop_column("plants", "category")
    op.drop_column("plants", "species_name")
    op.drop_column("plants", "species_scientific_name")
    op.drop_column("plants", "memo")
    op.drop_table("plant_characters")
    op.drop_table("plant_environments")


def _update_diaries_and_memos() -> None:
    op.create_table(
        "plant_daily_memos",
        sa.Column("plant_id", sa.UUID(), nullable=False),
        sa.Column("memo_date", sa.Date(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("id", sa.UUID(), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["plant_id"], ["plants.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("plant_id", "memo_date", name="uq_plant_daily_memos_plant_date"),
    )
    op.execute("ALTER TABLE public.plant_daily_memos ENABLE ROW LEVEL SECURITY")

    op.execute("DELETE FROM plant_diaries WHERE deleted_at IS NOT NULL")
    op.drop_constraint(
        op.f("ck_plant_diaries_condition_level"), "plant_diaries", type_="check"
    )
    op.drop_constraint(
        op.f("ck_plant_diaries_condition_score_mapping"), "plant_diaries", type_="check"
    )
    op.drop_column("plant_diaries", "condition_level")
    op.drop_column("plant_diaries", "deleted_at")
    op.create_check_constraint(
        op.f("ck_plant_diaries_condition_score"),
        "plant_diaries",
        "condition_score >= 0 AND condition_score <= 100",
    )


def _update_care() -> None:
    op.drop_constraint(
        op.f("ck_care_schedules_water_recommendation_source"),
        "care_schedules",
        type_="check",
    )
    op.alter_column(
        "care_schedules",
        "water_recommendation_source",
        new_column_name="recommendation_source",
    )
    op.create_check_constraint(
        op.f("ck_care_schedules_recommendation_source"),
        "care_schedules",
        "recommendation_source IS NULL OR recommendation_source = 'SPECIES_GUIDE'",
    )

    op.drop_index("ix_care_events_plant_id_scheduled_at", table_name="care_events")
    op.drop_index("ix_care_events_status_scheduled_at", table_name="care_events")
    op.drop_constraint(op.f("ck_care_events_status"), "care_events", type_="check")
    op.add_column("care_events", sa.Column("source", sa.String(length=24), nullable=True))
    op.add_column("care_events", sa.Column("due_date", sa.Date(), nullable=True))
    op.add_column("care_events", sa.Column("performed_on", sa.Date(), nullable=True))
    op.add_column(
        "care_events", sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.execute("UPDATE care_events SET status = 'SCHEDULED' WHERE status = 'OVERDUE'")
    op.execute(
        """
        UPDATE care_events
        SET due_date = scheduled_at::date,
            performed_on = CASE WHEN status = 'COMPLETED' THEN completed_at::date END,
            recorded_at = CASE WHEN status = 'COMPLETED' THEN completed_at END,
            source = CASE
                WHEN source_diagnosis_id IS NOT NULL THEN 'AI_RECOMMENDED'
                WHEN schedule_id IS NOT NULL THEN 'AUTO_SCHEDULE'
                ELSE 'USER_CREATED'
            END
        """
    )
    op.alter_column("care_events", "source", nullable=False)
    op.alter_column("care_events", "due_date", nullable=False)
    op.create_check_constraint(
        op.f("ck_care_events_status"),
        "care_events",
        "status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED')",
    )
    op.create_check_constraint(
        op.f("ck_care_events_source"),
        "care_events",
        "source IN ('AUTO_SCHEDULE', 'USER_CREATED', 'AI_RECOMMENDED')",
    )
    op.create_check_constraint(
        op.f("ck_care_events_completion_fields"),
        "care_events",
        "(status = 'COMPLETED' AND performed_on IS NOT NULL AND recorded_at IS NOT NULL) OR "
        "(status <> 'COMPLETED' AND performed_on IS NULL AND recorded_at IS NULL)",
    )
    op.drop_column("care_events", "scheduled_at")
    op.drop_column("care_events", "completed_at")
    op.drop_column("care_events", "note")
    op.create_index("ix_care_events_plant_id_due_date", "care_events", ["plant_id", "due_date"])
    op.create_index(
        "ix_care_events_plant_id_performed_on", "care_events", ["plant_id", "performed_on"]
    )
    op.create_index("ix_care_events_status_due_date", "care_events", ["status", "due_date"])


def _update_diagnoses() -> None:
    op.execute("DELETE FROM diagnoses WHERE deleted_at IS NOT NULL")
    op.add_column("diagnoses", sa.Column("media_file_id", sa.UUID(), nullable=True))
    op.execute(
        """
        UPDATE diagnoses AS d
        SET media_file_id = i.media_file_id
        FROM diagnosis_images AS i
        WHERE i.diagnosis_id = d.id
        """
    )
    op.alter_column("diagnoses", "media_file_id", nullable=False)
    op.create_foreign_key(
        "fk_diagnoses_media_file_id_media_files",
        "diagnoses",
        "media_files",
        ["media_file_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.drop_table("diagnosis_images")
    op.drop_constraint(
        op.f("ck_diagnoses_diagnosis_latency_ms"), "diagnoses", type_="check"
    )
    op.alter_column(
        "diagnoses",
        "diagnosis_provider_response_id",
        new_column_name="provider_response_id",
    )
    op.alter_column("diagnoses", "diagnosis_latency_ms", new_column_name="latency_ms")
    op.create_check_constraint(
        op.f("ck_diagnoses_latency_ms"),
        "diagnoses",
        "latency_ms IS NULL OR latency_ms >= 0",
    )
    op.drop_column("diagnoses", "symptom_started_on")
    op.drop_column("diagnoses", "user_note")
    op.drop_column("diagnoses", "explanation_provider")
    op.drop_column("diagnoses", "deleted_at")


def _update_chat() -> None:
    op.add_column("ai_conversations", sa.Column("plant_id", sa.UUID(), nullable=True))
    op.execute(
        """
        UPDATE ai_conversations AS c
        SET plant_id = ch.plant_id
        FROM ai_chats AS ch
        WHERE ch.id = c.chat_id
        """
    )
    op.alter_column("ai_conversations", "plant_id", nullable=False)
    op.create_foreign_key(
        "fk_ai_conversations_plant_id_plants",
        "ai_conversations",
        "plants",
        ["plant_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.drop_index(
        "ix_ai_conversations_chat_id_last_message_at", table_name="ai_conversations"
    )
    op.drop_index("ix_ai_conversations_chat_id_title", table_name="ai_conversations")
    op.drop_constraint(
        op.f("fk_ai_conversations_chat_id_ai_chats"),
        "ai_conversations",
        type_="foreignkey",
    )
    op.drop_column("ai_conversations", "chat_id")
    op.drop_column("ai_conversations", "provider_conversation_id")
    op.create_index(
        "ix_ai_conversations_plant_id_last_message_at",
        "ai_conversations",
        ["plant_id", sa.text("last_message_at DESC")],
    )
    op.create_index(
        "ix_ai_conversations_plant_id_title",
        "ai_conversations",
        ["plant_id", "title"],
    )
    op.drop_table("ai_chats")
    op.drop_constraint(op.f("ck_ai_actions_version"), "ai_actions", type_="check")
    op.drop_column("ai_actions", "version")


def _drop_deferred_features() -> None:
    op.drop_table("monthly_reports")
    op.drop_table("ai_batch_items")
    op.drop_table("ai_batch_jobs")
    op.drop_table("notification_settings")


def downgrade() -> None:
    raise RuntimeError("This consolidation removes unused empty tables and is not reversible.")
