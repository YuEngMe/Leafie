"""Unlink diagnoses from chat conversations.

Revision ID: a7d921e4b603
Revises: f1a8c3e05d92
"""

import sqlalchemy as sa

from alembic import op

revision = "a7d921e4b603"
down_revision = "f1a8c3e05d92"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint(
        "fk_diagnoses_related_conversation_id_ai_conversations",
        "diagnoses",
        type_="foreignkey",
    )
    op.drop_column("diagnoses", "related_conversation_id")


def downgrade() -> None:
    # Schema rollback cannot restore historical conversation associations.
    op.add_column("diagnoses", sa.Column("related_conversation_id", sa.UUID(), nullable=True))
    op.create_foreign_key(
        "fk_diagnoses_related_conversation_id_ai_conversations",
        "diagnoses",
        "ai_conversations",
        ["related_conversation_id"],
        ["id"],
        ondelete="SET NULL",
    )
