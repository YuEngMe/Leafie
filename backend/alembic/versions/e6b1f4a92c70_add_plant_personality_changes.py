"""add plant personality change history

Revision ID: e6b1f4a92c70
Revises: c4d8e1f72a90
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "e6b1f4a92c70"
down_revision = "c4d8e1f72a90"
branch_labels = None
depends_on = None


PERSONALITIES = "'OUTGOING', 'CHIC', 'CUTE', 'CRUSH', 'INTROVERTED', 'CHUNGCHEONG'"


def upgrade() -> None:
    op.create_table(
        "plant_personality_changes",
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
        sa.Column("previous_personality_type", sa.String(length=32), nullable=False),
        sa.Column("new_personality_type", sa.String(length=32), nullable=False),
        sa.Column(
            "changed_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            f"previous_personality_type IN ({PERSONALITIES})",
            name="previous_personality_type",
        ),
        sa.CheckConstraint(
            f"new_personality_type IN ({PERSONALITIES})",
            name="new_personality_type",
        ),
        sa.CheckConstraint(
            "previous_personality_type <> new_personality_type",
            name="personality_changed",
        ),
    )
    op.create_index(
        "ix_plant_personality_changes_plant_changed",
        "plant_personality_changes",
        ["plant_id", "changed_at"],
    )
    op.execute("ALTER TABLE public.plant_personality_changes ENABLE ROW LEVEL SECURITY")
    op.execute("REVOKE ALL ON public.plant_personality_changes FROM anon, authenticated")


def downgrade() -> None:
    op.drop_table("plant_personality_changes")
