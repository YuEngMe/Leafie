"""make species identification idempotent

Revision ID: 7d5a21c90e4b
Revises: 1f2e7c9a6b31
Create Date: 2026-07-29 05:20:00.000000
"""

from collections.abc import Sequence

from alembic import op

revision: str = "7d5a21c90e4b"
down_revision: str | Sequence[str] | None = "1f2e7c9a6b31"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_unique_constraint(
        "uq_species_identifications_media_file_id",
        "species_identifications",
        ["media_file_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_species_identifications_media_file_id",
        "species_identifications",
        type_="unique",
    )
