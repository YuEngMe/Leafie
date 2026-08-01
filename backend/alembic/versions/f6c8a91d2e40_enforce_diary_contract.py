"""enforce diary contract

Revision ID: f6c8a91d2e40
Revises: e4b7c2d91a60
Create Date: 2026-08-01 19:30:00.000000
"""

from collections.abc import Sequence

from alembic import op

revision: str = "f6c8a91d2e40"
down_revision: str | Sequence[str] | None = "e4b7c2d91a60"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # These DROP statements make the revision safe for the shared development
    # database, where the same constraints may already have been applied while
    # the team was reconciling concurrent Alembic heads.
    op.execute(
        "ALTER TABLE plant_diaries "
        "DROP CONSTRAINT IF EXISTS ck_plant_diaries_content_length"
    )
    op.create_check_constraint(
        op.f("ck_plant_diaries_content_length"),
        "plant_diaries",
        "char_length(btrim(content)) BETWEEN 1 AND 2000",
    )
    op.execute(
        "ALTER TABLE plant_diaries "
        "DROP CONSTRAINT IF EXISTS ck_plant_diaries_condition_score"
    )
    op.execute(
        """
        UPDATE plant_diaries
        SET condition_score = CASE
            WHEN condition_score < 13 THEN 0
            WHEN condition_score < 38 THEN 25
            WHEN condition_score < 63 THEN 50
            WHEN condition_score < 88 THEN 75
            ELSE 100
        END
        """
    )
    op.create_check_constraint(
        op.f("ck_plant_diaries_condition_score"),
        "plant_diaries",
        "condition_score IN (0, 25, 50, 75, 100)",
    )
    op.execute(
        "ALTER TABLE plant_diaries "
        "DROP CONSTRAINT IF EXISTS uq_plant_diaries_media_file_id"
    )
    op.create_unique_constraint(
        "uq_plant_diaries_media_file_id",
        "plant_diaries",
        ["media_file_id"],
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE plant_diaries "
        "DROP CONSTRAINT IF EXISTS uq_plant_diaries_media_file_id"
    )
    op.execute(
        "ALTER TABLE plant_diaries "
        "DROP CONSTRAINT IF EXISTS ck_plant_diaries_condition_score"
    )
    op.create_check_constraint(
        op.f("ck_plant_diaries_condition_score"),
        "plant_diaries",
        "condition_score >= 0 AND condition_score <= 100",
    )
    op.execute(
        "ALTER TABLE plant_diaries "
        "DROP CONSTRAINT IF EXISTS ck_plant_diaries_content_length"
    )
