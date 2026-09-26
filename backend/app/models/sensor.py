from datetime import datetime
from decimal import Decimal
from uuid import UUID

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Identity,
    Index,
    Numeric,
    SmallInteger,
    String,
    text,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.models.enums import SensorDeviceClaimStatus, SensorDeviceStatus, enum_values

# 식물 센서 장치. `device_tokens`(푸시 수신용 앱 설치 정보)와 무관하다.


class SensorDevice(Base, TimestampMixin):
    __tablename__ = "sensor_devices"
    __table_args__ = (
        # ESP가 MAC 주소로 만드는 12자리 대문자 hex (예: D40592E7D168)
        CheckConstraint("id ~ '^[0-9A-F]{12}$'", name="id_format"),
        CheckConstraint(f"status IN ({enum_values(SensorDeviceStatus)})", name="status"),
        CheckConstraint(
            "sensor_token_hash IS NULL OR char_length(sensor_token_hash) = 64",
            name="sensor_token_hash_length",
        ),
        # claim 성공 전에는 소유자와 토큰이 없고, 성공 이후에만 함께 채워진다.
        CheckConstraint(
            "(status = 'CLAIMED' AND owner_user_id IS NOT NULL "
            "AND sensor_token_hash IS NOT NULL AND claimed_at IS NOT NULL) "
            "OR (status = 'UNCLAIMED' AND owner_user_id IS NULL AND sensor_token_hash IS NULL)",
            name="claimed_state",
        ),
        Index("ix_sensor_devices_owner_user_id", "owner_user_id"),
        Index(
            "uq_sensor_devices_sensor_token_hash",
            "sensor_token_hash",
            unique=True,
            postgresql_where=text("sensor_token_hash IS NOT NULL"),
        ),
    )

    id: Mapped[str] = mapped_column(String(12), primary_key=True)
    owner_user_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE")
    )
    sensor_token_hash: Mapped[str | None] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=SensorDeviceStatus.UNCLAIMED.value
    )
    firmware_version: Mapped[str | None] = mapped_column(String(32))
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # 서버(백엔드)가 갱신한다. 수집 Lambda(sensor_ingest)는 sensor_devices를 수정하지 않는다.
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class SensorDeviceClaim(Base, UUIDPrimaryKeyMixin):
    """기기 claim "시도". `sensor_devices.owner_user_id`(현재 실제 소유자)와 의미가 다르다."""

    __tablename__ = "sensor_device_claims"
    __table_args__ = (
        CheckConstraint(f"status IN ({enum_values(SensorDeviceClaimStatus)})", name="status"),
        CheckConstraint(
            "char_length(claim_token_hash) = 64",
            name="claim_token_hash_length",
        ),
        CheckConstraint(
            "(status = 'COMPLETED') = (completed_at IS NOT NULL)",
            name="completed_at",
        ),
        Index("ix_sensor_device_claims_user_id", "user_id"),
        # 기기당 동시에 유효한 claim은 하나뿐이다 (여러 claim credential 동시 지원 안 함).
        Index(
            "uq_sensor_device_claims_pending_device",
            "device_id",
            unique=True,
            postgresql_where=text("status = 'PENDING'"),
        ),
    )

    device_id: Mapped[str] = mapped_column(
        String(12), ForeignKey("sensor_devices.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False
    )
    claim_token_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, server_default=SensorDeviceClaimStatus.PENDING.value
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class PlantSensorDevice(Base):
    """식물과 기기의 연결. 식물 하나에 기기 하나, 기기 하나에 식물 하나."""

    __tablename__ = "plant_sensor_devices"

    device_id: Mapped[str] = mapped_column(
        String(12), ForeignKey("sensor_devices.id", ondelete="CASCADE"), primary_key=True
    )
    plant_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("plants.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )


class SensorReading(Base):
    """기기가 10분마다 올리는 원시 측정값. SQS consumer(Lambda)가 INSERT만 한다."""

    __tablename__ = "sensor_readings"
    __table_args__ = (
        CheckConstraint("lux >= 0", name="lux_range"),
        CheckConstraint("soil_raw BETWEEN 0 AND 4095", name="soil_raw_range"),
        Index("ix_sensor_readings_device_received", "device_id", text("received_at DESC")),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    device_id: Mapped[str] = mapped_column(
        String(12), ForeignKey("sensor_devices.id", ondelete="CASCADE"), nullable=False
    )
    # 표준 SQS는 같은 메시지를 두 번 전달할 수 있어 messageId로 중복 저장을 막는다.
    sqs_message_id: Mapped[UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False, unique=True)
    # 기기 시계 기준. SNTP 동기화 전이면 null.
    measured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # SQS SentTimestamp = API Gateway가 요청을 받은 시각.
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    # 센서 읽기에 실패하면 null.
    lux: Mapped[Decimal | None] = mapped_column(Numeric(8, 1))
    soil_raw: Mapped[int | None] = mapped_column(SmallInteger)
