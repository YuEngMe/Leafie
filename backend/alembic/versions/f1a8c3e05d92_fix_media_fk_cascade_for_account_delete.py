"""fix media FK cascade for account delete

Revision ID: f1a8c3e05d92
Revises: e2f9b5d83c01
Create Date: 2026-08-03 18:45:00.000000
"""

from collections.abc import Sequence

from alembic import op

revision: str = "f1a8c3e05d92"
down_revision: str | Sequence[str] | None = "e2f9b5d83c01"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint(
        "fk_diagnoses_media_file_id_media_files",
        "diagnoses",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "fk_diagnoses_media_file_id_media_files",
        "diagnoses",
        "media_files",
        ["media_file_id"],
        ["id"],
        ondelete="CASCADE",
    )

    op.drop_constraint(
        "fk_species_identifications_media_file_id_media_files",
        "species_identifications",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "fk_species_identifications_media_file_id_media_files",
        "species_identifications",
        "media_files",
        ["media_file_id"],
        ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_species_identifications_media_file_id_media_files",
        "species_identifications",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "fk_species_identifications_media_file_id_media_files",
        "species_identifications",
        "media_files",
        ["media_file_id"],
        ["id"],
        ondelete="RESTRICT",
    )

    op.drop_constraint(
        "fk_diagnoses_media_file_id_media_files",
        "diagnoses",
        type_="foreignkey",
    )
    op.create_foreign_key(
        "fk_diagnoses_media_file_id_media_files",
        "diagnoses",
        "media_files",
        ["media_file_id"],
        ["id"],
        ondelete="RESTRICT",
    )
