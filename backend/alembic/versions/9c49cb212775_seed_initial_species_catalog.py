"""seed initial species catalog

Revision ID: 9c49cb212775
Revises: 599f9b555185
Create Date: 2026-07-29 02:00:00.000000
"""

import json
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "9c49cb212775"
down_revision: str | Sequence[str] | None = "599f9b555185"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

CATALOG = [
    {
        "species_reference_id": "catalog:monstera-deliciosa",
        "display_name": "몬스테라",
        "scientific_name": "Monstera deliciosa",
        "plantnet_species_id": "1385965",
        "gbif_id": 2868241,
        "powo_id": "87478-1",
        "aliases": ["몬스테라"],
        "taxon_rank": "SPECIES",
        "genus": "Monstera",
        "family": "Araceae",
        "category": "FOLIAGE",
    },
    {
        "species_reference_id": "catalog:epipremnum-aureum",
        "display_name": "스킨답서스",
        "scientific_name": "Epipremnum aureum",
        "plantnet_species_id": "1409602",
        "gbif_id": 2868323,
        "powo_id": "87014-1",
        "aliases": ["스킨답서스", "포토스", "골든 포토스"],
        "taxon_rank": "SPECIES",
        "genus": "Epipremnum",
        "family": "Araceae",
        "category": "FOLIAGE",
    },
    {
        "species_reference_id": "catalog:philodendron-hederaceum",
        "display_name": "필로덴드론",
        "scientific_name": "Philodendron hederaceum",
        "plantnet_species_id": "1404586",
        "gbif_id": 2871003,
        "powo_id": "87797-1",
        "aliases": ["필로덴드론", "하트리프 필로덴드론"],
        "taxon_rank": "SPECIES",
        "genus": "Philodendron",
        "family": "Araceae",
        "category": "FOLIAGE",
    },
    {
        "species_reference_id": "catalog:hedera-helix",
        "display_name": "아이비",
        "scientific_name": "Hedera helix",
        "plantnet_species_id": "1363575",
        "gbif_id": 8351737,
        "powo_id": "90723-1",
        "aliases": ["아이비", "잉글리시 아이비"],
        "taxon_rank": "SPECIES",
        "genus": "Hedera",
        "family": "Araliaceae",
        "category": "FOLIAGE",
    },
    {
        "species_reference_id": "catalog:zamioculcas-zamiifolia",
        "display_name": "금전수",
        "scientific_name": "Zamioculcas zamiifolia",
        "plantnet_species_id": "1752284",
        "gbif_id": 2869014,
        "powo_id": "89402-1",
        "aliases": ["금전수", "ZZ 플랜트"],
        "taxon_rank": "SPECIES",
        "genus": "Zamioculcas",
        "family": "Araceae",
        "category": "FOLIAGE",
    },
    {
        "species_reference_id": "catalog:dracaena-trifasciata",
        "display_name": "산세베리아",
        "scientific_name": "Dracaena trifasciata",
        "plantnet_species_id": "1718844",
        "gbif_id": 11041822,
        "powo_id": "77164235-1",
        "aliases": ["산세베리아", "스네이크 플랜트", "Sansevieria trifasciata"],
        "taxon_rank": "SPECIES",
        "genus": "Dracaena",
        "family": "Asparagaceae",
        "category": "FOLIAGE",
    },
    {
        "species_reference_id": "catalog:ficus-elastica",
        "display_name": "고무나무",
        "scientific_name": "Ficus elastica",
        "plantnet_species_id": "1403870",
        "gbif_id": 5361903,
        "powo_id": "60458499-2",
        "aliases": ["고무나무", "인도고무나무"],
        "taxon_rank": "SPECIES",
        "genus": "Ficus",
        "family": "Moraceae",
        "category": "FOLIAGE",
    },
    {
        "species_reference_id": "catalog:alocasia-mortfontanensis",
        "display_name": "알로카시아",
        "scientific_name": "Alocasia × mortfontanensis",
        "plantnet_species_id": "1843636",
        "gbif_id": 5532250,
        "powo_id": "84211-1",
        "aliases": ["알로카시아", "알로카시아 아마조니카", "Alocasia × amazonica"],
        "taxon_rank": "SPECIES",
        "genus": "Alocasia",
        "family": "Araceae",
        "category": "FOLIAGE",
    },
    {
        "species_reference_id": "catalog:rosa-chinensis",
        "display_name": "장미",
        "scientific_name": "Rosa chinensis",
        "plantnet_species_id": "1395231",
        "gbif_id": 3005039,
        "powo_id": "732029-1",
        "aliases": ["장미", "월계화"],
        "taxon_rank": "SPECIES",
        "genus": "Rosa",
        "family": "Rosaceae",
        "category": "FLOWER",
    },
    {
        "species_reference_id": "catalog:bellis-perennis",
        "display_name": "데이지",
        "scientific_name": "Bellis perennis",
        "plantnet_species_id": "1357317",
        "gbif_id": 3117424,
        "powo_id": "184409-1",
        "aliases": ["데이지", "잉글리시 데이지"],
        "taxon_rank": "SPECIES",
        "genus": "Bellis",
        "family": "Asteraceae",
        "category": "FLOWER",
    },
    {
        "species_reference_id": "catalog:helianthus-annuus",
        "display_name": "해바라기",
        "scientific_name": "Helianthus annuus",
        "plantnet_species_id": "1364145",
        "gbif_id": 9206251,
        "powo_id": "119003-2",
        "aliases": ["해바라기"],
        "taxon_rank": "SPECIES",
        "genus": "Helianthus",
        "family": "Asteraceae",
        "category": "FLOWER",
    },
    {
        "species_reference_id": "catalog:tulipa-gesneriana",
        "display_name": "튤립",
        "scientific_name": "Tulipa gesneriana",
        "plantnet_species_id": "1396919",
        "gbif_id": 5299675,
        "powo_id": "542923-1",
        "aliases": ["튤립", "정원튤립"],
        "taxon_rank": "SPECIES",
        "genus": "Tulipa",
        "family": "Liliaceae",
        "category": "FLOWER",
    },
    {
        "species_reference_id": "catalog:hydrangea-macrophylla",
        "display_name": "수국",
        "scientific_name": "Hydrangea macrophylla",
        "plantnet_species_id": "1361819",
        "gbif_id": 2985994,
        "powo_id": "791637-1",
        "aliases": ["수국", "큰잎수국"],
        "taxon_rank": "SPECIES",
        "genus": "Hydrangea",
        "family": "Hydrangeaceae",
        "category": "FLOWER",
    },
    {
        "species_reference_id": "catalog:cactaceae",
        "display_name": "선인장",
        "scientific_name": "Cactaceae",
        "plantnet_species_id": None,
        "gbif_id": 2519,
        "powo_id": None,
        "aliases": ["선인장", "칵투스"],
        "taxon_rank": "FAMILY",
        "genus": None,
        "family": "Cactaceae",
        "category": "SUCCULENT_CACTUS",
    },
    {
        "species_reference_id": "catalog:echeveria-elegans",
        "display_name": "에케베리아",
        "scientific_name": "Echeveria elegans",
        "plantnet_species_id": "1418517",
        "gbif_id": 8315197,
        "powo_id": "86934-2",
        "aliases": ["에케베리아", "멕시칸 스노우볼"],
        "taxon_rank": "SPECIES",
        "genus": "Echeveria",
        "family": "Crassulaceae",
        "category": "SUCCULENT_CACTUS",
    },
    {
        "species_reference_id": "catalog:haworthiopsis-attenuata",
        "display_name": "하월시아",
        "scientific_name": "Haworthiopsis attenuata",
        "plantnet_species_id": "1754606",
        "gbif_id": 9388529,
        "powo_id": "77138002-1",
        "aliases": ["하월시아", "호월시아", "Haworthia attenuata"],
        "taxon_rank": "SPECIES",
        "genus": "Haworthiopsis",
        "family": "Asphodelaceae",
        "category": "SUCCULENT_CACTUS",
    },
    {
        "species_reference_id": "catalog:olea-europaea",
        "display_name": "올리브나무",
        "scientific_name": "Olea europaea",
        "plantnet_species_id": "1359676",
        "gbif_id": 5415040,
        "powo_id": "610675-1",
        "aliases": ["올리브나무", "올리브"],
        "taxon_rank": "SPECIES",
        "genus": "Olea",
        "family": "Oleaceae",
        "category": "TREE",
    },
    {
        "species_reference_id": "catalog:mentha-spicata",
        "display_name": "민트",
        "scientific_name": "Mentha spicata",
        "plantnet_species_id": "1358788",
        "gbif_id": 2927175,
        "powo_id": "451162-1",
        "aliases": ["민트", "스피어민트"],
        "taxon_rank": "SPECIES",
        "genus": "Mentha",
        "family": "Lamiaceae",
        "category": "HERB",
    },
    {
        "species_reference_id": "catalog:ocimum-basilicum",
        "display_name": "바질",
        "scientific_name": "Ocimum basilicum",
        "plantnet_species_id": "1361975",
        "gbif_id": 2927096,
        "powo_id": "452874-1",
        "aliases": ["바질", "스위트 바질"],
        "taxon_rank": "SPECIES",
        "genus": "Ocimum",
        "family": "Lamiaceae",
        "category": "HERB",
    },
    {
        "species_reference_id": "catalog:fragaria-ananassa",
        "display_name": "딸기",
        "scientific_name": "Fragaria × ananassa",
        "plantnet_species_id": "1667445",
        "gbif_id": 3029912,
        "powo_id": "30117681-2",
        "aliases": ["딸기", "재배딸기", "가든 스트로베리"],
        "taxon_rank": "SPECIES",
        "genus": "Fragaria",
        "family": "Rosaceae",
        "category": "FRUIT",
    },
    {
        "species_reference_id": "catalog:citrus-limon",
        "display_name": "레몬",
        "scientific_name": "Citrus × limon",
        "plantnet_species_id": "1403436",
        "gbif_id": 7647136,
        "powo_id": "60454758-2",
        "aliases": ["레몬", "레몬나무", "Citrus limon"],
        "taxon_rank": "SPECIES",
        "genus": "Citrus",
        "family": "Rutaceae",
        "category": "FRUIT",
    },
    {
        "species_reference_id": "catalog:vaccinium-corymbosum",
        "display_name": "블루베리",
        "scientific_name": "Vaccinium corymbosum",
        "plantnet_species_id": "1396966",
        "gbif_id": 2882849,
        "powo_id": "261823-2",
        "aliases": ["블루베리", "하이부시 블루베리"],
        "taxon_rank": "SPECIES",
        "genus": "Vaccinium",
        "family": "Ericaceae",
        "category": "FRUIT",
    },
    {
        "species_reference_id": "catalog:prunus-avium",
        "display_name": "체리",
        "scientific_name": "Prunus avium",
        "plantnet_species_id": "1360316",
        "gbif_id": 3020791,
        "powo_id": "30093848-2",
        "aliases": ["체리", "체리나무", "양벚나무", "스위트 체리"],
        "taxon_rank": "SPECIES",
        "genus": "Prunus",
        "family": "Rosaceae",
        "category": "FRUIT",
    },
]


def upgrade() -> None:
    op.add_column(
        "species_care_guides", sa.Column("plantnet_species_id", sa.String(255), nullable=True)
    )
    op.add_column("species_care_guides", sa.Column("gbif_id", sa.BigInteger(), nullable=True))
    op.add_column("species_care_guides", sa.Column("powo_id", sa.String(100), nullable=True))
    op.add_column(
        "species_care_guides",
        sa.Column(
            "aliases",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "species_care_guides",
        sa.Column(
            "taxon_rank", sa.String(16), server_default=sa.text("'SPECIES'"), nullable=False
        ),
    )
    op.add_column("species_care_guides", sa.Column("genus", sa.String(100), nullable=True))
    op.add_column("species_care_guides", sa.Column("family", sa.String(100), nullable=True))
    op.create_check_constraint(
        "taxon_rank",
        "species_care_guides",
        "taxon_rank IN ('SPECIES', 'GENUS', 'FAMILY')",
    )
    op.create_index(
        "ix_species_care_guides_gbif_id",
        "species_care_guides",
        ["gbif_id"],
        unique=True,
    )
    op.create_index(
        "ix_species_care_guides_plantnet_species_id",
        "species_care_guides",
        ["plantnet_species_id"],
        unique=True,
        postgresql_where=sa.text("plantnet_species_id IS NOT NULL"),
    )

    catalog_table = sa.table(
        "species_care_guides",
        sa.column("species_reference_id", sa.String),
        sa.column("display_name", sa.String),
        sa.column("scientific_name", sa.String),
        sa.column("plantnet_species_id", sa.String),
        sa.column("gbif_id", sa.BigInteger),
        sa.column("powo_id", sa.String),
        sa.column("aliases", postgresql.JSONB),
        sa.column("taxon_rank", sa.String),
        sa.column("genus", sa.String),
        sa.column("family", sa.String),
        sa.column("category", sa.String),
    )
    rows = [
        {
            **item,
            "aliases": sa.cast(
                op.inline_literal(json.dumps(item["aliases"], ensure_ascii=False)),
                postgresql.JSONB,
            ),
        }
        for item in CATALOG
    ]
    insert = postgresql.insert(catalog_table).values(rows)
    update_columns = {
        column: getattr(insert.excluded, column)
        for column in (
            "display_name",
            "scientific_name",
            "plantnet_species_id",
            "gbif_id",
            "powo_id",
            "aliases",
            "taxon_rank",
            "genus",
            "family",
            "category",
        )
    }
    op.get_bind().execute(
        insert.on_conflict_do_update(
            index_elements=[catalog_table.c.species_reference_id],
            set_=update_columns,
        )
    )


def downgrade() -> None:
    catalog_table = sa.table(
        "species_care_guides",
        sa.column("species_reference_id", sa.String),
    )
    op.get_bind().execute(
        catalog_table.delete().where(
            catalog_table.c.species_reference_id.in_(
                [item["species_reference_id"] for item in CATALOG]
            )
        )
    )
    op.drop_index(
        "ix_species_care_guides_plantnet_species_id",
        table_name="species_care_guides",
        postgresql_where=sa.text("plantnet_species_id IS NOT NULL"),
    )
    op.drop_index("ix_species_care_guides_gbif_id", table_name="species_care_guides")
    op.drop_constraint(
        "ck_species_care_guides_taxon_rank",
        "species_care_guides",
        type_="check",
    )
    op.drop_column("species_care_guides", "family")
    op.drop_column("species_care_guides", "genus")
    op.drop_column("species_care_guides", "taxon_rank")
    op.drop_column("species_care_guides", "aliases")
    op.drop_column("species_care_guides", "powo_id")
    op.drop_column("species_care_guides", "gbif_id")
    op.drop_column("species_care_guides", "plantnet_species_id")
