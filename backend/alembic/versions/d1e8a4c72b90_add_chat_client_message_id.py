"""add chat client message id

Revision ID: d1e8a4c72b90
Revises: c4f9a2d8e710
Create Date: 2026-08-02 19:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "d1e8a4c72b90"
down_revision: str | Sequence[str] | None = "c4f9a2d8e710"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "ai_messages",
        sa.Column("client_message_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_index(
        "uq_ai_messages_conversation_client_message_id",
        "ai_messages",
        ["conversation_id", "client_message_id"],
        unique=True,
        postgresql_where=sa.text("client_message_id IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_ai_messages_conversation_client_message_id",
        table_name="ai_messages",
    )
    op.drop_column("ai_messages", "client_message_id")
