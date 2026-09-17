"""refactor care calendar contract

Revision ID: c4d8e1f72a90
Revises: f3a7c9d42e10
"""

import sqlalchemy as sa

from alembic import op

revision = "c4d8e1f72a90"
down_revision = "f3a7c9d42e10"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Removed care types are outside the new product contract. Delete their
    # notifications first because notification.source_id has no database FK.
    op.execute(
        """
        DELETE FROM notifications
        WHERE source_type = 'CARE_EVENT'
          AND source_id IN (
              SELECT id FROM care_events WHERE type IN ('PRUNING', 'CUSTOM')
          )
        """
    )
    op.execute("DELETE FROM care_events WHERE type IN ('PRUNING', 'CUSTOM')")

    op.drop_constraint(op.f("ck_care_events_custom_event"), "care_events", type_="check")
    op.drop_constraint(op.f("ck_care_events_type"), "care_events", type_="check")
    op.drop_column("care_events", "title")
    op.create_check_constraint(
        op.f("ck_care_events_type"),
        "care_events",
        "type IN ('WATERING', 'REPOTTING', 'FERTILIZING')",
    )

    op.drop_table("plant_daily_memos")


def downgrade() -> None:
    op.create_table(
        "plant_daily_memos",
        sa.Column("plant_id", sa.UUID(), nullable=False),
        sa.Column("memo_date", sa.Date(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "id",
            sa.UUID(),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "char_length(btrim(content, E' \\t\\n\\r\\f\\v')) BETWEEN 1 AND 500",
            name=op.f("ck_plant_daily_memos_content_length"),
        ),
        sa.ForeignKeyConstraint(["plant_id"], ["plants.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "plant_id", "memo_date", name="uq_plant_daily_memos_plant_date"
        ),
    )
    op.execute("ALTER TABLE public.plant_daily_memos ENABLE ROW LEVEL SECURITY")

    op.drop_constraint(op.f("ck_care_events_type"), "care_events", type_="check")
    op.add_column("care_events", sa.Column("title", sa.String(length=200)))
    op.create_check_constraint(
        op.f("ck_care_events_type"),
        "care_events",
        "type IN ('WATERING', 'REPOTTING', 'FERTILIZING', 'PRUNING', 'CUSTOM')",
    )
    op.create_check_constraint(
        op.f("ck_care_events_custom_event"),
        "care_events",
        "(type <> 'CUSTOM') OR (title IS NOT NULL AND schedule_id IS NULL)",
    )
