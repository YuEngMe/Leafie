from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_current_user, get_database_session
from app.api.v1 import plants as plants_api
from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.enums import SensorConnection
from app.schemas.sensor import (
    PlantSensorDailyLight,
    PlantSensorLatestReading,
    PlantSensorStatusResponse,
)
from app.services.sensor_status import (
    SOIL_RAW_DRY,
    SOIL_RAW_WET,
    LatestReadingRow,
    SensorStatusService,
    soil_raw_to_percent,
)

DEVICE_ID = "D40592E7D168"
NOW = datetime(2026, 10, 1, 3, 0, tzinfo=UTC)  # 12:00 KST


class FakeSensorStatusRepository:
    def __init__(self) -> None:
        self.timezones: dict[tuple[UUID, UUID], str] = {}  # (user_id, plant_id) -> timezone
        self.links: dict[UUID, str] = {}  # plant_id -> device_id
        self.latest: dict[str, LatestReadingRow] = {}
        self.lux_sum = Decimal("0")
        self.lux_window: tuple[datetime, datetime] | None = None

    async def get_owned_plant_timezone(self, user_id: UUID, plant_id: UUID) -> str | None:
        return self.timezones.get((user_id, plant_id))

    async def get_linked_device_id(self, plant_id: UUID) -> str | None:
        return self.links.get(plant_id)

    async def get_latest_reading(self, device_id: str) -> LatestReadingRow | None:
        return self.latest.get(device_id)

    async def sum_lux(self, device_id: str, start: datetime, end: datetime) -> Decimal:
        self.lux_window = (start, end)
        return self.lux_sum


def reading(
    *,
    lux: str | None = "100.0",
    soil_raw: int | None = 2300,
    received_at: datetime = NOW - timedelta(minutes=5),
) -> LatestReadingRow:
    return LatestReadingRow(
        lux=Decimal(lux) if lux is not None else None,
        soil_raw=soil_raw,
        measured_at=received_at,
        received_at=received_at,
    )


def linked_repository(user_id: UUID, plant_id: UUID, timezone: str = "Asia/Seoul"):
    repository = FakeSensorStatusRepository()
    repository.timezones[(user_id, plant_id)] = timezone
    repository.links[plant_id] = DEVICE_ID
    return repository


@pytest.mark.parametrize(
    ("soil_raw", "percent"),
    [
        (SOIL_RAW_DRY, 0),
        (SOIL_RAW_WET, 100),
        ((SOIL_RAW_DRY + SOIL_RAW_WET) // 2, 50),
        (SOIL_RAW_DRY + 500, 0),
        (SOIL_RAW_WET - 500, 100),
        (0, 100),
        (4095, 0),
    ],
)
def test_soil_raw_to_percent_is_linear_and_clamped(soil_raw: int, percent: int) -> None:
    assert soil_raw_to_percent(soil_raw) == percent


async def test_unowned_plant_is_not_found() -> None:
    repository = FakeSensorStatusRepository()

    with pytest.raises(AppError) as error:
        await SensorStatusService(repository).get_owned_status(uuid4(), uuid4(), now=NOW)

    assert error.value.code == "PLANT_NOT_FOUND"
    assert error.value.status_code == 404


async def test_plant_without_device_returns_no_device_with_empty_fields() -> None:
    user_id, plant_id = uuid4(), uuid4()
    repository = FakeSensorStatusRepository()
    repository.timezones[(user_id, plant_id)] = "Asia/Seoul"

    result = await SensorStatusService(repository).get_owned_status(user_id, plant_id, now=NOW)

    assert result == PlantSensorStatusResponse(
        plant_id=plant_id,
        device_id=None,
        connection=SensorConnection.NO_DEVICE,
        latest=None,
        daily_light=None,
    )


async def test_linked_device_without_readings_returns_no_data() -> None:
    user_id, plant_id = uuid4(), uuid4()
    repository = linked_repository(user_id, plant_id)

    result = await SensorStatusService(repository).get_owned_status(user_id, plant_id, now=NOW)

    assert result.connection == SensorConnection.NO_DATA
    assert result.device_id == DEVICE_ID
    assert result.latest is None
    assert result.daily_light is None


async def test_recent_reading_is_active_with_latest_and_soil_percent() -> None:
    user_id, plant_id = uuid4(), uuid4()
    repository = linked_repository(user_id, plant_id)
    row = reading(lux="123.4", soil_raw=(SOIL_RAW_DRY + SOIL_RAW_WET) // 2)
    repository.latest[DEVICE_ID] = row

    result = await SensorStatusService(repository).get_owned_status(user_id, plant_id, now=NOW)

    assert result.connection == SensorConnection.ACTIVE
    assert result.latest == PlantSensorLatestReading(
        lux=123.4,
        soil_percent=50,
        measured_at=row.measured_at,
        received_at=row.received_at,
    )


async def test_reading_older_than_threshold_is_stale() -> None:
    user_id, plant_id = uuid4(), uuid4()
    repository = linked_repository(user_id, plant_id)
    repository.latest[DEVICE_ID] = reading(received_at=NOW - timedelta(minutes=31))

    result = await SensorStatusService(repository).get_owned_status(user_id, plant_id, now=NOW)

    assert result.connection == SensorConnection.STALE
    assert result.latest is not None


async def test_failed_soil_read_has_no_soil_percent() -> None:
    user_id, plant_id = uuid4(), uuid4()
    repository = linked_repository(user_id, plant_id)
    repository.latest[DEVICE_ID] = reading(lux=None, soil_raw=None)

    result = await SensorStatusService(repository).get_owned_status(user_id, plant_id, now=NOW)

    assert result.latest is not None
    assert result.latest.lux is None
    assert result.latest.soil_percent is None


async def test_daily_light_is_lux_sum_times_sample_interval_in_user_timezone_day() -> None:
    user_id, plant_id = uuid4(), uuid4()
    repository = linked_repository(user_id, plant_id, "Asia/Seoul")
    repository.latest[DEVICE_ID] = reading()
    repository.lux_sum = Decimal("6000.0")  # 6000 lux × 10분 = 1000 lux·h

    result = await SensorStatusService(repository).get_owned_status(user_id, plant_id, now=NOW)

    assert result.daily_light == PlantSensorDailyLight(date=date(2026, 10, 1), lux_hours=1000.0)
    # 2026-10-01 00:00 ~ 2026-10-02 00:00 KST
    assert repository.lux_window == (
        datetime(2026, 9, 30, 15, 0, tzinfo=UTC),
        datetime(2026, 10, 1, 15, 0, tzinfo=UTC),
    )


async def test_status_for_explicit_day_uses_that_day_and_timezone() -> None:
    plant_id = uuid4()
    repository = FakeSensorStatusRepository()
    repository.links[plant_id] = DEVICE_ID
    repository.latest[DEVICE_ID] = reading()

    result = await SensorStatusService(repository).get_plant_status(
        plant_id, "America/New_York", day=date(2026, 9, 20), now=NOW
    )

    assert result.daily_light is not None
    assert result.daily_light.date == date(2026, 9, 20)
    assert repository.lux_window == (
        datetime(2026, 9, 20, 4, 0, tzinfo=UTC),  # EDT(UTC-4) 자정
        datetime(2026, 9, 21, 4, 0, tzinfo=UTC),
    )


async def test_invalid_timezone_falls_back_to_seoul() -> None:
    plant_id = uuid4()
    repository = FakeSensorStatusRepository()
    repository.links[plant_id] = DEVICE_ID
    repository.latest[DEVICE_ID] = reading()

    result = await SensorStatusService(repository).get_plant_status(plant_id, "Not/AZone", now=NOW)

    assert result.daily_light is not None
    assert result.daily_light.date == date(2026, 10, 1)


def test_plant_sensor_status_http_contract(monkeypatch) -> None:
    plant_id = uuid4()
    measured_at = datetime(2026, 10, 1, 2, 55, tzinfo=UTC)
    status_service = SimpleNamespace(
        get_owned_status=AsyncMock(
            return_value=PlantSensorStatusResponse(
                plant_id=plant_id,
                device_id=DEVICE_ID,
                connection=SensorConnection.ACTIVE,
                latest=PlantSensorLatestReading(
                    lux=123.4, soil_percent=50, measured_at=measured_at, received_at=measured_at
                ),
                daily_light=PlantSensorDailyLight(date=date(2026, 10, 1), lux_hours=1000.0),
            )
        )
    )

    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=uuid4(), email=None, role=None, claims={}
    )
    app.dependency_overrides[get_database_session] = lambda: object()
    monkeypatch.setattr(plants_api, "build_sensor_status_service", lambda _session: status_service)
    client = TestClient(app)

    response = client.get(f"/api/v1/plants/{plant_id}/sensor/status")

    assert response.status_code == 200
    assert response.json() == {
        "plantId": str(plant_id),
        "deviceId": DEVICE_ID,
        "connection": "ACTIVE",
        "latest": {
            "lux": 123.4,
            "soilPercent": 50,
            "measuredAt": "2026-10-01T02:55:00Z",
            "receivedAt": "2026-10-01T02:55:00Z",
        },
        "dailyLight": {"date": "2026-10-01", "luxHours": 1000.0},
    }
