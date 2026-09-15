"""drop legacy chat and tool-calling data

Revision ID: f3a7c9d42e10
Revises: d8b4f1c62a90
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "f3a7c9d42e10"
down_revision = "d8b4f1c62a90"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint(
        "fk_ai_conversations_summarized_through_message_id_ai_messages",
        "ai_conversations",
        type_="foreignkey",
    )
    op.drop_table("ai_actions")
    op.drop_table("ai_tool_calls")
    op.drop_table("ai_messages")
    op.drop_table("ai_conversations")

    # Chat photos have no remaining product owner. Remove their metadata before
    # tightening the allowed upload purposes; Storage cleanup is a deploy pre-step.
    op.execute("DELETE FROM media_files WHERE purpose = 'CHAT'")
    op.drop_constraint(op.f("ck_media_files_purpose"), "media_files", type_="check")
    op.create_check_constraint(
        op.f("ck_media_files_purpose"),
        "media_files",
        "purpose IN ('PLANT_PROFILE', 'SPECIES_IDENTIFICATION', 'DIARY', 'DIAGNOSIS')",
    )


def downgrade() -> None:
    op.drop_constraint(op.f("ck_media_files_purpose"), "media_files", type_="check")
    op.create_check_constraint(
        op.f("ck_media_files_purpose"),
        "media_files",
        "purpose IN ('PLANT_PROFILE', 'SPECIES_IDENTIFICATION', 'DIARY', 'DIAGNOSIS', 'CHAT')",
    )

    op.create_table(
        "ai_conversations",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "plant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("plants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("context_summary", sa.Text()),
        sa.Column("summarized_through_message_id", postgresql.UUID(as_uuid=True)),
        sa.Column("summary_version", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("summary_updated_at", sa.DateTime(timezone=True)),
        sa.Column("last_message_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint("summary_version >= 0", name=op.f("ck_ai_conversations_summary_version")),
    )
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

    op.create_table(
        "ai_messages",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "conversation_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("ai_conversations.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("client_message_id", postgresql.UUID(as_uuid=True)),
        sa.Column(
            "related_diagnosis_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("diagnoses.id", ondelete="SET NULL"),
        ),
        sa.Column(
            "media_file_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("media_files.id", ondelete="SET NULL"),
        ),
        sa.Column("role", sa.String(16), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default=sa.text("'COMPLETED'")),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("provider", sa.String(100)),
        sa.Column("model_name", sa.String(200)),
        sa.Column("provider_response_id", sa.String(255)),
        sa.Column("input_tokens", sa.Integer()),
        sa.Column("output_tokens", sa.Integer()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")
        ),
        sa.CheckConstraint(
            "role IN ('USER', 'ASSISTANT', 'SYSTEM')", name=op.f("ck_ai_messages_role")
        ),
        sa.CheckConstraint(
            "status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED')",
            name=op.f("ck_ai_messages_status"),
        ),
        sa.CheckConstraint(
            "input_tokens IS NULL OR input_tokens >= 0",
            name=op.f("ck_ai_messages_input_tokens"),
        ),
        sa.CheckConstraint(
            "output_tokens IS NULL OR output_tokens >= 0",
            name=op.f("ck_ai_messages_output_tokens"),
        ),
    )
    op.create_index(
        "ix_ai_messages_conversation_id_created_at",
        "ai_messages",
        ["conversation_id", "created_at"],
    )
    op.create_index(
        "uq_ai_messages_conversation_client_message_id",
        "ai_messages",
        ["conversation_id", "client_message_id"],
        unique=True,
        postgresql_where=sa.text("client_message_id IS NOT NULL"),
    )

    op.create_table(
        "ai_actions",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("auth.users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "message_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("ai_messages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "plant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("plants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("action_type", sa.String(100), nullable=False),
        sa.Column("payload", postgresql.JSONB(), nullable=False),
        sa.Column(
            "status",
            sa.String(32),
            nullable=False,
            server_default=sa.text("'PENDING_CONFIRMATION'"),
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True)),
        sa.Column("confirmed_at", sa.DateTime(timezone=True)),
        sa.Column("executed_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")
        ),
        sa.CheckConstraint(
            "status IN ('PENDING_CONFIRMATION', 'EXECUTING', 'COMPLETED', "
            "'CANCELLED', 'EXPIRED', 'FAILED')",
            name=op.f("ck_ai_actions_status"),
        ),
    )
    op.create_index(
        "ix_ai_actions_user_id_status_expires_at",
        "ai_actions",
        ["user_id", "status", "expires_at"],
    )

    op.create_table(
        "ai_tool_calls",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "message_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("ai_messages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("provider_call_id", sa.String(255), nullable=False, unique=True),
        sa.Column("tool_name", sa.String(100), nullable=False),
        sa.Column("arguments", postgresql.JSONB(), nullable=False),
        sa.Column("result_summary", postgresql.JSONB()),
        sa.Column("status", sa.String(16), nullable=False, server_default=sa.text("'PENDING'")),
        sa.Column("latency_ms", sa.Integer()),
        sa.Column("error_code", sa.String(100)),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint(
            "status IN ('PENDING', 'COMPLETED', 'FAILED')",
            name=op.f("ck_ai_tool_calls_status"),
        ),
        sa.CheckConstraint(
            "latency_ms IS NULL OR latency_ms >= 0",
            name=op.f("ck_ai_tool_calls_latency_ms"),
        ),
    )
    op.create_index(
        "ix_ai_tool_calls_message_id_created_at",
        "ai_tool_calls",
        ["message_id", "created_at"],
    )
    op.create_foreign_key(
        "fk_ai_conversations_summarized_through_message_id_ai_messages",
        "ai_conversations",
        "ai_messages",
        ["summarized_through_message_id"],
        ["id"],
        ondelete="SET NULL",
    )

    for table_name in ("ai_conversations", "ai_messages", "ai_actions", "ai_tool_calls"):
        op.execute(f"ALTER TABLE public.{table_name} ENABLE ROW LEVEL SECURITY")
        op.execute(f"REVOKE ALL ON public.{table_name} FROM anon, authenticated")
