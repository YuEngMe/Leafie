"""make plant registration idempotent

Revision ID: d2f4a8c91b73
Revises: c9e2f7a1d640
Create Date: 2026-08-01 18:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "d2f4a8c91b73"
down_revision: str | Sequence[str] | None = "c9e2f7a1d640"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "plants",
        sa.Column(
            "client_registration_id",
            postgresql.UUID(as_uuid=True),
            nullable=False,
            server_default=sa.text("gen_random_uuid()"),
        ),
    )
    op.add_column(
        "plants",
        sa.Column(
            "registration_request_hash",
            sa.String(length=64),
            nullable=False,
            server_default=sa.text("repeat('0', 64)"),
        ),
    )
    op.alter_column("plants", "client_registration_id", server_default=None)
    op.alter_column("plants", "registration_request_hash", server_default=None)
    op.create_check_constraint(
        op.f("ck_plants_registration_request_hash_length"),
        "plants",
        "char_length(registration_request_hash) = 64",
    )
    op.create_unique_constraint(
        "uq_plants_user_client_registration_id",
        "plants",
        ["user_id", "client_registration_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_plants_user_client_registration_id",
        "plants",
        type_="unique",
    )
    op.drop_constraint(
        op.f("ck_plants_registration_request_hash_length"),
        "plants",
        type_="check",
    )
    op.drop_column("plants", "registration_request_hash")
    op.drop_column("plants", "client_registration_id")
