"""drop redundant diary index

Revision ID: b4d7e1a6c930
Revises: a8f31c2d9e40
Create Date: 2026-07-31 22:30:00.000000
"""

from collections.abc import Sequence

from alembic import op

revision: str = "b4d7e1a6c930"
down_revision: str | Sequence[str] | None = "a8f31c2d9e40"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_index("ix_plant_diaries_plant_id_diary_date", table_name="plant_diaries")


def downgrade() -> None:
    op.create_index(
        "ix_plant_diaries_plant_id_diary_date",
        "plant_diaries",
        ["plant_id", "diary_date"],
    )
