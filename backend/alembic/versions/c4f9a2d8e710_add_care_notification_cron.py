"""add care notification cron

Revision ID: c4f9a2d8e710
Revises: b8e4c1a72d90
Create Date: 2026-08-02 20:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "c4f9a2d8e710"
down_revision: str | Sequence[str] | None = "b8e4c1a72d90"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "uq_notifications_source",
        "notifications",
        ["user_id", "type", "source_type", "source_id"],
        unique=True,
        postgresql_where=sa.text("source_id IS NOT NULL"),
    )
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_cron")
    op.execute(
        """
        SELECT cron.schedule(
            'leafie-care-notification-collector',
            '0 * * * *',
            $$
            SELECT * FROM pgmq.send(
                'leafie_jobs',
                '{
                    "job_type": "CARE_NOTIFICATION_COLLECT",
                    "resource_id": "00000000-0000-0000-0000-000000000001",
                    "attempt": 0,
                    "trace_id": "cron:care-notifications"
                }'::jsonb
            )
            $$
        )
        """
    )


def downgrade() -> None:
    op.execute("SELECT cron.unschedule('leafie-care-notification-collector')")
    op.drop_index("uq_notifications_source", table_name="notifications")
