"""Add fenced execution leases for diagnosis and species workers."""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "d2f6a83b9c10"
down_revision = "b7e3a91d6f20"
branch_labels = None
depends_on = None


def upgrade() -> None:
    for table in ("diagnoses", "species_identifications"):
        op.add_column(table, sa.Column("lease_token", postgresql.UUID(as_uuid=True)))
        op.add_column(table, sa.Column("lease_until", sa.DateTime(timezone=True)))
        op.add_column(
            table, sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0")
        )


def downgrade() -> None:
    for table in ("species_identifications", "diagnoses"):
        for column in ("attempt_count", "lease_until", "lease_token"):
            op.drop_column(table, column)
