"""Seed provisional species sensor policy and durable sensor events."""

import json

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "b6e2d8a41f90"
down_revision = "a4c9e1b73d58"
branch_labels = None
depends_on = None

VERSION = "2026-10-02.app-v1"
# Product defaults for relative sensor feedback, not species-specific agronomic measurements.
SOIL = {"DRY": (15, 75), "TOP_DRY": (30, 85), "LIGHT_MOIST": (35, 85), "MOIST": (40, 90)}
LIGHT = {"LOW_BRIGHT": (8000, 60000), "INDIRECT": (20000, 90000), "SUN": (60000, None)}
SPECIES = {
    "monstera-deliciosa": ("LIGHT_MOIST", "INDIRECT"),
    "epipremnum-aureum": ("TOP_DRY", "LOW_BRIGHT"),
    "philodendron-hederaceum": ("LIGHT_MOIST", "LOW_BRIGHT"),
    "hedera-helix": ("MOIST", "INDIRECT"),
    "zamioculcas-zamiifolia": ("DRY", "LOW_BRIGHT"),
    "dracaena-trifasciata": ("DRY", "LOW_BRIGHT"),
    "ficus-elastica": ("TOP_DRY", "INDIRECT"),
    "alocasia-mortfontanensis": ("MOIST", "INDIRECT"),
    "rosa-chinensis": ("MOIST", "SUN"),
    "bellis-perennis": ("MOIST", "SUN"),
    "helianthus-annuus": ("MOIST", "SUN"),
    "tulipa-gesneriana": ("MOIST", "SUN"),
    "hydrangea-macrophylla": ("MOIST", "INDIRECT"),
    "cactaceae": ("DRY", "SUN"),
    "echeveria-elegans": ("DRY", "SUN"),
    "haworthiopsis-attenuata": ("DRY", "INDIRECT"),
    "olea-europaea": ("TOP_DRY", "SUN"),
    "mentha-spicata": ("MOIST", "SUN"),
    "ocimum-basilicum": ("MOIST", "SUN"),
    "fragaria-ananassa": ("MOIST", "SUN"),
    "citrus-limon": ("LIGHT_MOIST", "SUN"),
    "vaccinium-corymbosum": ("MOIST", "SUN"),
    "prunus-avium": ("LIGHT_MOIST", "SUN"),
}


def policy(species: str) -> dict:
    soil, light = SPECIES[species]
    return {
        "version": VERSION,
        "status": "PROVISIONAL",
        "enabled": species != "tulipa-gesneriana",
        "soil_unit": "relative_percent",
        "light_unit": "lux_hours",
        "soil_percent": dict(zip(("lower", "upper"), SOIL[soil], strict=True)),
        "light_lux_hours": dict(zip(("lower", "upper"), LIGHT[light], strict=True)),
        "basis": "APP_INITIAL_HEURISTIC_NOT_AGRONOMIC_STANDARD",
        "assumptions": [
            "Relative soil readings require device/substrate calibration (#118).",
            "Lux-hours are not PAR-based DLI; values are app feedback targets, not injury limits.",
            "Light is evaluated for a completed local day with >=80% ten-minute coverage.",
            "Tulip policy stays disabled until growth/dormancy is known.",
            "Cactaceae is a family-level app default, not a species-specific measured threshold.",
        ],
        "reference_urls": [
            "https://www.extension.umd.edu/resource/lighting-indoor-plants",
            "https://content.ces.ncsu.edu/calibrating-soil-water-measuring-devices",
        ],
        "references_supply_numeric_thresholds": False,
    }


def upgrade() -> None:
    for species in SPECIES:
        op.execute(
            sa.text(
                "UPDATE species_care_guides SET care_profile = "
                "care_profile || jsonb_build_object('sensor_thresholds', CAST(:policy AS jsonb)) "
                "WHERE species_reference_id = :reference AND NOT care_profile ? 'sensor_thresholds'"
            ).bindparams(policy=json.dumps(policy(species)), reference=f"catalog:{species}")
        )
    op.create_table(
        "plant_sensor_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "plant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("plants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("device_id", sa.String(12), nullable=False),
        sa.Column("evaluation_date", sa.Date, nullable=False),
        sa.Column("type", sa.String(16), nullable=False),
        sa.Column("value", sa.Numeric(12, 2), nullable=False),
        sa.Column("threshold_version", sa.String(32), nullable=False),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "plant_id", "device_id", "evaluation_date", "type", name="uq_plant_sensor_events_daily"
        ),
        sa.CheckConstraint(
            "type IN ('SOIL_LOW', 'SOIL_HIGH', 'LIGHT_LOW', 'LIGHT_HIGH')", name="type"
        ),
    )
    op.create_index(
        "ix_plant_sensor_events_plant_occurred", "plant_sensor_events", ["plant_id", "occurred_at"]
    )
    op.execute("ALTER TABLE public.plant_sensor_events ENABLE ROW LEVEL SECURITY")
    op.execute("REVOKE ALL ON public.plant_sensor_events FROM anon, authenticated")
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_cron")
    op.execute("""
        SELECT cron.schedule('leafie-sensor-notification-collector', '*/10 * * * *', $$
        SELECT * FROM pgmq.send('leafie_jobs', '{"job_type":"SENSOR_NOTIFICATION_COLLECT",
        "resource_id":"00000000-0000-0000-0000-000000000002","attempt": 0,
        "trace_id":"cron:sensor-notifications"}'::jsonb) $$)
    """)


def downgrade() -> None:
    op.execute("SELECT cron.unschedule('leafie-sensor-notification-collector')")
    op.drop_table("plant_sensor_events")
    for species in SPECIES:
        op.execute(
            sa.text(
                "UPDATE species_care_guides SET care_profile = care_profile - 'sensor_thresholds' "
                "WHERE species_reference_id = :reference "
                "AND care_profile->'sensor_thresholds' = CAST(:policy AS jsonb)"
            ).bindparams(reference=f"catalog:{species}", policy=json.dumps(policy(species)))
        )
