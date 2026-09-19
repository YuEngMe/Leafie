"""add selectable plant expression

Revision ID: a9d4e7f2c610
Revises: f8a2d6c41b70
"""

import sqlalchemy as sa

from alembic import op

revision = "a9d4e7f2c610"
down_revision = "f8a2d6c41b70"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("plants", sa.Column("expression_id", sa.String(length=100), nullable=True))
    op.execute(
        "UPDATE plants SET expression_id = 'expression_default' WHERE expression_id IS NULL"
    )
    op.alter_column("plants", "expression_id", nullable=False)
    op.create_check_constraint(
        "expression_id",
        "plants",
        "expression_id IN "
        "('expression_default', 'expression_happy', 'expression_neutral', 'expression_sad')",
    )


def downgrade() -> None:
    op.drop_constraint("expression_id", "plants", type_="check")
    op.drop_column("plants", "expression_id")
