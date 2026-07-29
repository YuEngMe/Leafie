"""add account deletion status

Revision ID: 4c2d9f7a6b10
Revises: 7d5a21c90e4b
Create Date: 2026-07-29 06:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "4c2d9f7a6b10"
down_revision: str | Sequence[str] | None = "7d5a21c90e4b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "user_profiles",
        sa.Column("deletion_status", sa.String(length=16), nullable=True),
    )
    op.execute("UPDATE user_profiles SET deletion_status = 'PENDING' WHERE deleted_at IS NOT NULL")
    op.create_check_constraint(
        "ck_user_profiles_deletion_state",
        "user_profiles",
        "(deleted_at IS NULL AND deletion_status IS NULL) OR "
        "(deleted_at IS NOT NULL AND deletion_status IN ('PENDING', 'FAILED'))",
    )
    op.create_index(
        "ix_user_profiles_deletion_status",
        "user_profiles",
        ["deletion_status"],
    )


def downgrade() -> None:
    op.drop_index("ix_user_profiles_deletion_status", table_name="user_profiles")
    op.drop_constraint(
        "ck_user_profiles_deletion_state",
        "user_profiles",
        type_="check",
    )
    op.drop_column("user_profiles", "deletion_status")
