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

from app.db.base import Base, TimestampMixin


class SensorDevice(Base, TimestampMixin):
    """식물 센서 장치. `device_tokens`(푸시 수신 설치 정보)와 무관하다."""

    __tablename__ = "sensor_devices"
    __table_args__ = (
        CheckConstraint("device_id ~ '^[0-9A-F]{12}$'", name="device_id_format"),
        Index("ix_sensor_devices_user_id", "user_id"),
        Index(
            "uq_sensor_devices_plant_id",
            "plant_id",
            unique=True,
            postgresql_where=text("plant_id IS NOT NULL"),
        ),
    )

    # ESP가 MAC 주소로 만드는 12자리 대문자 hex (예: D40592E7D168)
    device_id: Mapped[str] = mapped_column(String(12), primary_key=True)
    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("auth.users.id", ondelete="CASCADE"), nullable=False
    )
    plant_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("plants.id", ondelete="SET NULL")
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
        String(12), ForeignKey("sensor_devices.device_id", ondelete="CASCADE"), nullable=False
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
