"""add care schedule contract

Revision ID: b8e4c1a72d90
Revises: a1c7d4e9f2b6
Create Date: 2026-08-02 18:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "b8e4c1a72d90"
down_revision: str | Sequence[str] | None = "a1c7d4e9f2b6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "care_events",
        sa.Column("client_event_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.add_column(
        "care_events",
        sa.Column("creation_request_hash", sa.String(length=64), nullable=True),
    )
    op.create_unique_constraint(
        "uq_care_events_plant_client_event",
        "care_events",
        ["plant_id", "client_event_id"],
    )

    op.execute(
        """
        INSERT INTO care_events (
            id,
            plant_id,
            schedule_id,
            type,
            status,
            source,
            due_date,
            created_at,
            updated_at
        )
        SELECT
            gen_random_uuid(),
            schedules.plant_id,
            schedules.id,
            schedules.type,
            'SCHEDULED',
            'AUTO_SCHEDULE',
            schedules.next_due_date,
            now(),
            now()
        FROM care_schedules AS schedules
        WHERE schedules.enabled = true
          AND NOT EXISTS (
              SELECT 1
              FROM care_events AS events
              WHERE events.schedule_id = schedules.id
                AND events.status = 'SCHEDULED'
          )
        """
    )
    op.create_index(
        "uq_care_events_schedule_scheduled",
        "care_events",
        ["schedule_id"],
        unique=True,
        postgresql_where=sa.text("status = 'SCHEDULED' AND schedule_id IS NOT NULL"),
    )

    op.create_check_constraint(
        op.f("ck_plant_daily_memos_content_length"),
        "plant_daily_memos",
        "char_length(btrim(content, E' \\t\\n\\r\\f\\v')) BETWEEN 1 AND 500",
    )


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_plant_daily_memos_content_length"),
        "plant_daily_memos",
        type_="check",
    )
    op.drop_index("uq_care_events_schedule_scheduled", table_name="care_events")
    op.drop_constraint(
        "uq_care_events_plant_client_event",
        "care_events",
        type_="unique",
    )
    op.drop_column("care_events", "creation_request_hash")
    op.drop_column("care_events", "client_event_id")
