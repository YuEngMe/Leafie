"""preserve superseded care event request keys

Revision ID: b7e3a91d6f20
Revises: cd31c92afd23
"""

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

from alembic import op

revision = "b7e3a91d6f20"
down_revision = "cd31c92afd23"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "care_events",
        sa.Column(
            "previous_request_hashes", JSONB, nullable=False, server_default=sa.text("'{}'::jsonb")
        ),
    )


def downgrade() -> None:
    op.drop_column("care_events", "previous_request_hashes")
