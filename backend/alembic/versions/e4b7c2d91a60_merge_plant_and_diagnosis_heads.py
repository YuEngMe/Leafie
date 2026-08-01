"""merge plant registration and diagnosis heads

Revision ID: e4b7c2d91a60
Revises: d2f4a8c91b73, d3a6f8b21c04
Create Date: 2026-08-01 19:02:00.000000
"""

from collections.abc import Sequence

revision: str = "e4b7c2d91a60"
down_revision: str | Sequence[str] | None = (
    "d2f4a8c91b73",
    "d3a6f8b21c04",
)
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
