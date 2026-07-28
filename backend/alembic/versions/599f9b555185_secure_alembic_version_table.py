"""secure alembic version table

Revision ID: 599f9b555185
Revises: fe7d184ad42b
Create Date: 2026-07-28 23:58:04.380403
"""

from collections.abc import Sequence

from alembic import op

revision: str = "599f9b555185"
down_revision: str | Sequence[str] | None = "fe7d184ad42b"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TABLE public.alembic_version ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE public.alembic_version DISABLE ROW LEVEL SECURITY")
