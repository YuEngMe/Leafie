"""simplify plant registration contract

Revision ID: c7a9e2d41f80
Revises: b2f416a83d09
"""

import sqlalchemy as sa

from alembic import op

revision = "c7a9e2d41f80"
down_revision = "b2f416a83d09"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_constraint(op.f("ck_plants_pot_type"), "plants", type_="check")
    op.drop_constraint(op.f("ck_plants_placement"), "plants", type_="check")
    op.drop_column("plants", "accessory_id")
    op.drop_column("plants", "placement")
    op.drop_column("plants", "pot_type")
    op.alter_column(
        "plants",
        "nickname",
        existing_type=sa.String(length=100),
        type_=sa.String(length=30),
        existing_nullable=False,
    )
    op.alter_column(
        "plants",
        "place_name",
        existing_type=sa.String(length=100),
        type_=sa.String(length=50),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "plants",
        "place_name",
        existing_type=sa.String(length=50),
        type_=sa.String(length=100),
        existing_nullable=False,
    )
    op.alter_column(
        "plants",
        "nickname",
        existing_type=sa.String(length=30),
        type_=sa.String(length=100),
        existing_nullable=False,
    )
    op.add_column(
        "plants",
        sa.Column("pot_type", sa.String(length=32), nullable=False, server_default="OTHER"),
    )
    op.add_column(
        "plants",
        sa.Column("placement", sa.String(length=32), nullable=False, server_default="OTHER"),
    )
    op.add_column(
        "plants",
        sa.Column("accessory_id", sa.String(length=100), nullable=False, server_default="NONE"),
    )
    op.create_check_constraint(
        op.f("ck_plants_pot_type"),
        "plants",
        "pot_type IN ('TERRACOTTA', 'PLASTIC', 'GLASS', 'CERAMIC', 'HYDROPONIC', 'OTHER')",
    )
    op.create_check_constraint(
        op.f("ck_plants_placement"),
        "plants",
        "placement IN ('VERANDA', 'WINDOW', 'LIVING_ROOM', 'BEDROOM', 'DESK', 'OTHER')",
    )
    op.alter_column("plants", "pot_type", server_default=None)
    op.alter_column("plants", "placement", server_default=None)
    op.alter_column("plants", "accessory_id", server_default=None)
