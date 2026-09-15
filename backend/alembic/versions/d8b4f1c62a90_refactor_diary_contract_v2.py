"""refactor diary contract v2

Revision ID: d8b4f1c62a90
Revises: c7a9e2d41f80
"""

import sqlalchemy as sa

from alembic import op

revision = "d8b4f1c62a90"
down_revision = "c7a9e2d41f80"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 전환 이전 다이어리는 내용을 조작하지 않고 null로 보존한다.
    op.add_column("plant_diaries", sa.Column("weather", sa.String(length=20)))
    op.add_column("plant_diaries", sa.Column("title", sa.String(length=100)))
    op.create_check_constraint(
        op.f("ck_plant_diaries_weather"),
        "plant_diaries",
        "weather IS NULL OR weather IN "
        "('SUNNY', 'PARTLY_CLOUDY', 'CLOUDY', 'RAINY', 'SNOWY')",
    )
    op.create_check_constraint(
        op.f("ck_plant_diaries_title_length"),
        "plant_diaries",
        "title IS NULL OR "
        "char_length(btrim(title, E' \\t\\n\\r\\f\\v')) BETWEEN 1 AND 100",
    )
    op.drop_constraint(
        op.f("ck_plant_diaries_condition_score"),
        "plant_diaries",
        type_="check",
    )
    op.drop_column("plant_diaries", "condition_score")


def downgrade() -> None:
    # 제거한 과거 점수는 복원할 수 없으므로 중립값으로만 되돌린다.
    op.add_column(
        "plant_diaries",
        sa.Column("condition_score", sa.Integer(), nullable=False, server_default="50"),
    )
    op.create_check_constraint(
        op.f("ck_plant_diaries_condition_score"),
        "plant_diaries",
        "condition_score IN (0, 25, 50, 75, 100)",
    )
    op.alter_column("plant_diaries", "condition_score", server_default=None)
    op.drop_constraint(
        op.f("ck_plant_diaries_title_length"),
        "plant_diaries",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_plant_diaries_weather"),
        "plant_diaries",
        type_="check",
    )
    op.drop_column("plant_diaries", "title")
    op.drop_column("plant_diaries", "weather")
