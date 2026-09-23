"""add sensor devices and readings

Revision ID: cd31c92afd23
Revises: a9d4e7f2c610

센서 소유 테이블과 telemetry consumer(Lambda) 전용 DB 역할 `sensor_ingest`를 추가한다.
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


def upgrade() -> None:
    op.create_table(
        "sensor_devices",
        sa.Column("device_id", sa.String(12), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("auth.users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "plant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("plants.id", ondelete="SET NULL"),
        ),
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
        sa.CheckConstraint("device_id ~ '^[0-9A-F]{12}$'", name="device_id_format"),
    )
    op.create_index("ix_sensor_devices_user_id", "sensor_devices", ["user_id"])
    op.create_index(
        "uq_sensor_devices_plant_id",
        "sensor_devices",
        ["plant_id"],
        unique=True,
        postgresql_where=sa.text("plant_id IS NOT NULL"),
    )

    op.create_table(
        "sensor_readings",
        sa.Column("id", sa.BigInteger(), sa.Identity(always=True), primary_key=True),
        sa.Column(
            "device_id",
            sa.String(12),
            sa.ForeignKey("sensor_devices.device_id", ondelete="CASCADE"),
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
    for table_name in ("sensor_devices", "sensor_readings"):
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
    op.drop_table("sensor_devices")
    op.execute(
        "DO $$ BEGIN "
        "IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sensor_ingest') THEN "
        "REVOKE USAGE ON SCHEMA public FROM sensor_ingest; "
        "DROP ROLE sensor_ingest; "
        "END IF; END $$"
    )
