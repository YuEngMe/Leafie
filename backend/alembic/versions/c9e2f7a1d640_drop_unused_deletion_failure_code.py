"""drop unused deletion failure code

Revision ID: c9e2f7a1d640
Revises: b4d7e1a6c930
Create Date: 2026-07-31 23:10:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "c9e2f7a1d640"
down_revision: str | Sequence[str] | None = "b4d7e1a6c930"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_column("user_profiles", "deletion_failure_code")


def downgrade() -> None:
    op.add_column(
        "user_profiles",
        sa.Column("deletion_failure_code", sa.String(length=100), nullable=True),
    )
