from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy.exc import IntegrityError

from app.api.dependencies import get_current_user, get_database_session
from app.api.v1 import sensor as sensor_api
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.enums import SensorDeviceStatus
from app.models.sensor import SensorDevice
from app.schemas.sensor import SensorDeviceRegisterRequest, SensorDeviceResponse
from app.services.sensor import (
    SensorDeviceRegistrationResult,
    SensorDeviceService,
    SQLAlchemySensorDeviceRepository,
)

DEVICE_ID = "D40592E7D168"


class FakeSensorDeviceRepository:
    def __init__(self) -> None:
        self.devices: dict[str, SensorDevice] = {}
        self.add_calls = 0

    async def get(self, device_id: str) -> SensorDevice | None:
        return self.devices.get(device_id)

    async def add(self, device: SensorDevice) -> tuple[SensorDevice, bool]:
        self.add_calls += 1
        self.devices[device.id] = device
        return device, True


class FakeNestedTransaction:
    async def __aenter__(self) -> "FakeNestedTransaction":
        return self

    async def __aexit__(self, exc_type, exc, tb) -> bool:
        return False


class FakeSession:
    """`begin_nested`/`flush`/`scalar` 삼박자만 흉내 낸 동시 등록 경쟁 시뮬레이션용 세션."""

    def __init__(self, *, existing: SensorDevice | None, fail_flush: bool) -> None:
        self._existing = existing
        self._fail_flush = fail_flush

    def begin_nested(self) -> FakeNestedTransaction:
        return FakeNestedTransaction()

    def add(self, _instance: SensorDevice) -> None:
        pass

    async def flush(self) -> None:
        if self._fail_flush:
            raise IntegrityError("insert", {}, Exception("duplicate key"))

    async def scalar(self, _statement) -> SensorDevice | None:
        return self._existing


def unclaimed_device(device_id: str = DEVICE_ID) -> SensorDevice:
    return SensorDevice(id=device_id, status=SensorDeviceStatus.UNCLAIMED.value)


def claimed_device(device_id: str = DEVICE_ID) -> SensorDevice:
    return SensorDevice(
        id=device_id,
        status=SensorDeviceStatus.CLAIMED.value,
        owner_user_id=uuid4(),
        sensor_token_hash="a" * 64,
    )


def test_request_schema_requires_twelve_character_uppercase_hex() -> None:
    SensorDeviceRegisterRequest.model_validate({"deviceId": DEVICE_ID})

    with pytest.raises(ValidationError):
        SensorDeviceRegisterRequest.model_validate({"deviceId": DEVICE_ID.lower()})
    with pytest.raises(ValidationError):
        SensorDeviceRegisterRequest.model_validate({"deviceId": DEVICE_ID[:-1]})


async def test_register_new_device_creates_unclaimed_row() -> None:
    repository = FakeSensorDeviceRepository()
    service = SensorDeviceService(repository)

    result = await service.register_device(DEVICE_ID)

    assert result.created is True
    assert result.response.device_id == DEVICE_ID
    assert result.response.status == SensorDeviceStatus.UNCLAIMED
    assert repository.add_calls == 1


async def test_register_existing_unclaimed_device_is_idempotent() -> None:
    repository = FakeSensorDeviceRepository()
    repository.devices[DEVICE_ID] = unclaimed_device()
    service = SensorDeviceService(repository)

    result = await service.register_device(DEVICE_ID)

    assert result.created is False
    assert result.response.status == SensorDeviceStatus.UNCLAIMED
    assert repository.add_calls == 0


async def test_register_existing_claimed_device_keeps_state_and_hides_owner() -> None:
    repository = FakeSensorDeviceRepository()
    existing = claimed_device()
    repository.devices[DEVICE_ID] = existing

    result = await SensorDeviceService(repository).register_device(DEVICE_ID)

    assert result.created is False
    assert result.response.status == SensorDeviceStatus.CLAIMED
    assert "owner" not in SensorDeviceResponse.model_fields
    assert repository.devices[DEVICE_ID] is existing
    assert repository.add_calls == 0


async def test_repository_add_returns_created_true_on_success() -> None:
    session = FakeSession(existing=None, fail_flush=False)
    repository = SQLAlchemySensorDeviceRepository(session)
    device = unclaimed_device()

    stored, created = await repository.add(device)

    assert stored is device
    assert created is True


async def test_repository_add_resolves_concurrent_insert_conflict() -> None:
    existing = unclaimed_device()
    session = FakeSession(existing=existing, fail_flush=True)
    repository = SQLAlchemySensorDeviceRepository(session)

    stored, created = await repository.add(unclaimed_device())

    assert stored is existing
    assert created is False


def test_register_endpoint_returns_201_then_200_and_422_on_bad_format(monkeypatch) -> None:
    service = SimpleNamespace(
        register_device=AsyncMock(
            side_effect=[
                SensorDeviceRegistrationResult(
                    response=SensorDeviceResponse(
                        device_id=DEVICE_ID, status=SensorDeviceStatus.UNCLAIMED
                    ),
                    created=True,
                ),
                SensorDeviceRegistrationResult(
                    response=SensorDeviceResponse(
                        device_id=DEVICE_ID, status=SensorDeviceStatus.UNCLAIMED
                    ),
                    created=False,
                ),
            ]
        )
    )

    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=uuid4(), email=None, role=None, claims={}
    )
    app.dependency_overrides[get_database_session] = lambda: object()
    monkeypatch.setattr(sensor_api, "build_service", lambda _session: service)
    client = TestClient(app)

    created = client.post("/api/v1/sensor-devices", json={"deviceId": DEVICE_ID})
    assert created.status_code == 201
    assert created.json() == {"deviceId": DEVICE_ID, "status": "UNCLAIMED"}

    idempotent = client.post("/api/v1/sensor-devices", json={"deviceId": DEVICE_ID})
    assert idempotent.status_code == 200

    invalid = client.post("/api/v1/sensor-devices", json={"deviceId": "not-hex"})
    assert invalid.status_code == 422
