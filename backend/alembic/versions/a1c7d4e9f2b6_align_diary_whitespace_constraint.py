"""align diary whitespace constraint

Revision ID: a1c7d4e9f2b6
Revises: f6c8a91d2e40
Create Date: 2026-08-02 12:00:00.000000
"""

from collections.abc import Sequence

from alembic import op

revision: str = "a1c7d4e9f2b6"
down_revision: str | Sequence[str] | None = "f6c8a91d2e40"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # f6c8a91d2e40 was already applied to the shared development database
    # before this review fix, so a follow-up revision is required there.
    op.execute(
        "ALTER TABLE plant_diaries "
        "DROP CONSTRAINT IF EXISTS ck_plant_diaries_content_length"
    )
    op.create_check_constraint(
        op.f("ck_plant_diaries_content_length"),
        "plant_diaries",
        "char_length(btrim(content, E' \\t\\n\\r\\f\\v')) BETWEEN 1 AND 2000",
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE plant_diaries "
        "DROP CONSTRAINT IF EXISTS ck_plant_diaries_content_length"
    )
    op.create_check_constraint(
        op.f("ck_plant_diaries_content_length"),
        "plant_diaries",
        "char_length(btrim(content)) BETWEEN 1 AND 2000",
    )
