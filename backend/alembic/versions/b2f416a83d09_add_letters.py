"""add letters without backfilling existing diaries

Revision ID: b2f416a83d09
Revises: f1a8c3e05d92
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "b2f416a83d09"
down_revision = "f1a8c3e05d92"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "letters",
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
        sa.Column(
            "diary_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("plant_diaries.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("diary_date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="PENDING"),
        sa.Column("content", sa.Text()),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True)),
        sa.Column("generated_at", sa.DateTime(timezone=True)),
        sa.Column("published_at", sa.DateTime(timezone=True)),
        sa.Column("read_at", sa.DateTime(timezone=True)),
        sa.Column("lease_token", postgresql.UUID(as_uuid=True)),
        sa.Column("lease_until", sa.DateTime(timezone=True)),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("input_snapshot", postgresql.JSONB()),
        sa.Column("provider", sa.String(32)),
        sa.Column("model", sa.String(100)),
        sa.Column("provider_response_id", sa.String(255)),
        sa.Column("input_tokens", sa.Integer()),
        sa.Column("output_tokens", sa.Integer()),
        sa.Column("failure_code", sa.String(100)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint(
            "status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED')", name="status"
        ),
        sa.CheckConstraint("attempt_count >= 0", name="attempt_count"),
        sa.CheckConstraint(
            "status != 'COMPLETED' OR (content IS NOT NULL AND length(btrim(content)) > 0 "
            "AND generated_at IS NOT NULL)",
            name="completed_content",
        ),
        sa.CheckConstraint(
            "published_at IS NULL OR (status = 'COMPLETED' AND published_at >= scheduled_at)",
            name="publication",
        ),
        sa.CheckConstraint(
            "read_at IS NULL OR published_at IS NOT NULL", name="read_after_publication"
        ),
    )
    op.create_index("ix_letters_plant_published", "letters", ["plant_id", "published_at", "id"])
    op.create_index("ix_letters_status_lease", "letters", ["status", "lease_until"])
    # Only the backend role may read snapshots or write generation/publication state.
    op.execute("ALTER TABLE public.letters ENABLE ROW LEVEL SECURITY")
    op.execute("REVOKE ALL ON public.letters FROM anon, authenticated")


def downgrade() -> None:
    op.drop_table("letters")
