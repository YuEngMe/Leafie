"""add selectable plant body

Revision ID: f8a2d6c41b70
Revises: e6b1f4a92c70
"""

import sqlalchemy as sa

from alembic import op

revision = "f8a2d6c41b70"
down_revision = "e6b1f4a92c70"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("plants", sa.Column("body_id", sa.String(length=100), nullable=True))
    op.execute("UPDATE plants SET body_id = 'body_circle' WHERE body_id IS NULL")
    op.alter_column("plants", "body_id", nullable=False)
    op.create_check_constraint(
        "body_id",
        "plants",
        "body_id IN ('body_circle', 'body_thumb', 'body_square')",
    )


def downgrade() -> None:
    op.drop_constraint("body_id", "plants", type_="check")
    op.drop_column("plants", "body_id")
