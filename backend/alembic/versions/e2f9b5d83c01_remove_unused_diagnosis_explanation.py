"""remove unused diagnosis explanation metadata

Revision ID: e2f9b5d83c01
Revises: d1e8a4c72b90
Create Date: 2026-08-02 19:10:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "e2f9b5d83c01"
down_revision: str | Sequence[str] | None = "d1e8a4c72b90"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_column("diagnoses", "explanation_prompt_version")
    op.drop_column("diagnoses", "explanation_model_name")


def downgrade() -> None:
    op.add_column(
        "diagnoses",
        sa.Column("explanation_model_name", sa.String(length=200), nullable=True),
    )
    op.add_column(
        "diagnoses",
        sa.Column("explanation_prompt_version", sa.String(length=100), nullable=True),
    )
