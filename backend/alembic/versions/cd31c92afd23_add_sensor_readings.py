"""add devices, device claims, plant links and sensor readings

Revision ID: cd31c92afd23
Revises: a9d4e7f2c610

센서 소유 테이블(devices, device_claims, plant_devices, sensor_readings)과 telemetry
consumer(Lambda) 전용 DB 역할 `sensor_ingest`를 추가한다.
역할 비밀번호는 migration에 넣지 않는다. 적용 후 운영자가 별도로 설정한다.

    ALTER ROLE sensor_ingest PASSWORD '...';
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "cd31c92afd23"
down_revision = "a9d4e7f2c610"
branch_labels = None
depends_on = None

SENSOR_TABLES = ("devices", "device_claims", "plant_devices", "sensor_readings")


def upgrade() -> None:
    op.create_table(
        "devices",
        sa.Column("id", sa.String(12), primary_key=True),
        sa.Column(
            "owner_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("auth.users.id", ondelete="CASCADE"),
        ),
        sa.Column("device_token_hash", sa.String(64)),
        sa.Column("status", sa.String(16), nullable=False, server_default="UNCLAIMED"),
        sa.Column("firmware_version", sa.String(32)),
        sa.Column("claimed_at", sa.DateTime(timezone=True)),
        sa.Column("last_seen_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint("id ~ '^[0-9A-F]{12}$'", name="id_format"),
        sa.CheckConstraint("status IN ('UNCLAIMED', 'CLAIMED')", name="status"),
        sa.CheckConstraint(
            "device_token_hash IS NULL OR char_length(device_token_hash) = 64",
            name="device_token_hash_length",
        ),
        sa.CheckConstraint(
            "(status = 'CLAIMED' AND owner_user_id IS NOT NULL "
            "AND device_token_hash IS NOT NULL AND claimed_at IS NOT NULL) "
            "OR (status = 'UNCLAIMED' AND owner_user_id IS NULL AND device_token_hash IS NULL)",
            name="claimed_state",
        ),
    )
    op.create_index("ix_devices_owner_user_id", "devices", ["owner_user_id"])
    op.create_index(
        "uq_devices_device_token_hash",
        "devices",
        ["device_token_hash"],
        unique=True,
        postgresql_where=sa.text("device_token_hash IS NOT NULL"),
    )

    op.create_table(
        "device_claims",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "device_id",
            sa.String(12),
            sa.ForeignKey("devices.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("auth.users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("claim_token_hash", sa.String(64), nullable=False, unique=True),
        sa.Column("status", sa.String(16), nullable=False, server_default="PENDING"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint(
            "status IN ('PENDING', 'COMPLETED', 'EXPIRED', 'CANCELLED')", name="status"
        ),
        sa.CheckConstraint("char_length(claim_token_hash) = 64", name="claim_token_hash_length"),
        sa.CheckConstraint(
            "(status = 'COMPLETED') = (completed_at IS NOT NULL)", name="completed_at"
        ),
    )
    op.create_index("ix_device_claims_user_id", "device_claims", ["user_id"])
    op.create_index(
        "uq_device_claims_pending_device",
        "device_claims",
        ["device_id"],
        unique=True,
        postgresql_where=sa.text("status = 'PENDING'"),
    )

    op.create_table(
        "plant_devices",
        sa.Column(
            "device_id",
            sa.String(12),
            sa.ForeignKey("devices.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "plant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("plants.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )

    op.create_table(
        "sensor_readings",
        sa.Column("id", sa.BigInteger(), sa.Identity(always=True), primary_key=True),
        sa.Column(
            "device_id",
            sa.String(12),
            sa.ForeignKey("devices.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("sqs_message_id", postgresql.UUID(as_uuid=True), nullable=False, unique=True),
        sa.Column("measured_at", sa.DateTime(timezone=True)),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("lux", sa.Numeric(8, 1)),
        sa.Column("soil_raw", sa.SmallInteger()),
        sa.CheckConstraint("lux >= 0", name="lux_range"),
        sa.CheckConstraint("soil_raw BETWEEN 0 AND 4095", name="soil_raw_range"),
    )
    op.create_index(
        "ix_sensor_readings_device_received",
        "sensor_readings",
        ["device_id", sa.text("received_at DESC")],
    )

    # 앱(anon/authenticated)은 센서 테이블에 직접 접근하지 않는다. 백엔드 역할만 읽고 쓴다.
    for table_name in SENSOR_TABLES:
        op.execute(f"ALTER TABLE public.{table_name} ENABLE ROW LEVEL SECURITY")
        op.execute(f"REVOKE ALL ON public.{table_name} FROM anon, authenticated")

    # telemetry consumer 전용 역할: sensor_readings INSERT만 허용한다.
    op.execute(
        "DO $$ BEGIN CREATE ROLE sensor_ingest LOGIN NOINHERIT; "
        "EXCEPTION WHEN duplicate_object THEN NULL; END $$"
    )
    op.execute("GRANT USAGE ON SCHEMA public TO sensor_ingest")
    op.execute("GRANT INSERT ON public.sensor_readings TO sensor_ingest")
    op.execute(
        "CREATE POLICY sensor_ingest_insert ON public.sensor_readings "
        "FOR INSERT TO sensor_ingest WITH CHECK (true)"
    )


def downgrade() -> None:
    op.drop_table("sensor_readings")
    op.drop_table("plant_devices")
    op.drop_table("device_claims")
    op.drop_table("devices")
    op.execute(
        "DO $$ BEGIN "
        "IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sensor_ingest') THEN "
        "REVOKE USAGE ON SCHEMA public FROM sensor_ingest; "
        "DROP ROLE sensor_ingest; "
        "END IF; END $$"
    )
