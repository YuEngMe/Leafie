"""make diagnosis media idempotent

Revision ID: d3a6f8b21c04
Revises: c9e2f7a1d640
Create Date: 2026-08-01 18:10:00.000000
"""

from collections.abc import Sequence

from alembic import op

revision: str = "d3a6f8b21c04"
down_revision: str | Sequence[str] | None = "c9e2f7a1d640"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_unique_constraint(
        "uq_diagnoses_media_file_id",
        "diagnoses",
        ["media_file_id"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_diagnoses_media_file_id", "diagnoses", type_="unique")
