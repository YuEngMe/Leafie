from datetime import UTC, datetime
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_current_user, get_database_session
from app.api.v1 import plants as plants_api
from app.api.v1 import sensor as sensor_api
from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.enums import SensorDeviceStatus
from app.models.plant import Plant
from app.models.sensor import PlantSensorDevice, SensorDevice
from app.schemas.sensor import (
    PlantSensorDeviceResponse,
    SensorDeviceListItemResponse,
    SensorDeviceListResponse,
)
from app.services.sensor_management import SensorDeviceListRow, SensorDeviceManagementService

DEVICE_ID = "D40592E7D168"
OTHER_DEVICE_ID = "AAAAAAAAAAAA"


class FakeSensorDeviceManagementRepository:
    def __init__(self) -> None:
        self.devices: dict[str, SensorDevice] = {}
        self.plants: dict[UUID, Plant] = {}
        self.links: dict[UUID, str] = {}  # plant_id -> device_id
        self.readings: dict[str, tuple[Decimal, int, datetime]] = {}
        self.add_link_calls = 0

    async def list_devices(self, user_id: UUID) -> list[SensorDeviceListRow]:
        rows = []
        for device in self.devices.values():
            if device.owner_user_id != user_id:
                continue
            plant_id = next(
                (pid for pid, did in self.links.items() if did == device.id), None
            )
            reading = self.readings.get(device.id)
            rows.append(
                SensorDeviceListRow(
                    device=device,
                    plant_id=plant_id,
                    lux=reading[0] if reading else None,
                    soil_raw=reading[1] if reading else None,
                    measured_at=reading[2] if reading else None,
                )
            )
        return rows

    async def get_owned_device(self, user_id: UUID, device_id: str) -> SensorDevice | None:
        device = self.devices.get(device_id)
        if device is None or device.owner_user_id != user_id:
            return None
        return device

    async def get_owned_plant(self, user_id: UUID, plant_id: UUID) -> Plant | None:
        plant = self.plants.get(plant_id)
        if plant is None or plant.user_id != user_id:
            return None
        return plant

    async def remove_existing_links(self, *, plant_id: UUID, device_id: str) -> None:
        for existing_plant_id in [
            pid
            for pid, did in self.links.items()
            if pid == plant_id or did == device_id
        ]:
            del self.links[existing_plant_id]

    async def add_link(self, link: PlantSensorDevice) -> None:
        self.add_link_calls += 1
        self.links[link.plant_id] = link.device_id

    async def delete_link_for_plant(self, plant_id: UUID) -> None:
        self.links.pop(plant_id, None)

    async def release_device(self, device: SensorDevice, user_id: UUID) -> bool:
        if device.owner_user_id != user_id:
            return False
        for plant_id in [pid for pid, did in self.links.items() if did == device.id]:
            del self.links[plant_id]
        device.status = SensorDeviceStatus.UNCLAIMED.value
        device.owner_user_id = None
        device.sensor_token_hash = None
        device.claimed_at = None
        return True

    async def flush(self) -> None:
        pass


def claimed_device(device_id: str, owner_id: UUID) -> SensorDevice:
    return SensorDevice(
        id=device_id,
        owner_user_id=owner_id,
        sensor_token_hash="a" * 64,
        status=SensorDeviceStatus.CLAIMED.value,
        claimed_at=datetime.now(UTC),
        last_seen_at=None,
    )


def owned_plant(user_id: UUID) -> Plant:
    return Plant(id=uuid4(), user_id=user_id, deleted_at=None)


async def test_list_devices_only_returns_caller_owned_devices() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    repository.devices[DEVICE_ID] = claimed_device(DEVICE_ID, user_id)
    repository.devices[OTHER_DEVICE_ID] = claimed_device(OTHER_DEVICE_ID, uuid4())

    result = await SensorDeviceManagementService(repository).list_devices(user_id)

    assert [item.device_id for item in result.items] == [DEVICE_ID]


async def test_list_devices_includes_plant_link_and_latest_reading() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    plant_id = uuid4()
    measured_at = datetime.now(UTC)
    repository.devices[DEVICE_ID] = claimed_device(DEVICE_ID, user_id)
    repository.links[plant_id] = DEVICE_ID
    repository.readings[DEVICE_ID] = (Decimal("123.4"), 2048, measured_at)

    result = await SensorDeviceManagementService(repository).list_devices(user_id)

    item = result.items[0]
    assert item.plant_id == plant_id
    assert item.lux == Decimal("123.4")
    assert item.soil_raw == 2048
    assert item.measured_at == measured_at


async def test_connect_plant_device_rejects_unowned_plant() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    repository.devices[DEVICE_ID] = claimed_device(DEVICE_ID, user_id)

    with pytest.raises(AppError) as error:
        await SensorDeviceManagementService(repository).connect_plant_device(
            user_id, uuid4(), DEVICE_ID
        )

    assert error.value.code == "PLANT_NOT_FOUND"
    assert error.value.status_code == 404


async def test_connect_plant_device_rejects_unowned_device() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    plant = owned_plant(user_id)
    repository.plants[plant.id] = plant
    repository.devices[DEVICE_ID] = claimed_device(DEVICE_ID, uuid4())

    with pytest.raises(AppError) as error:
        await SensorDeviceManagementService(repository).connect_plant_device(
            user_id, plant.id, DEVICE_ID
        )

    assert error.value.code == "SENSOR_DEVICE_NOT_FOUND"
    assert error.value.status_code == 404


async def test_connect_plant_device_succeeds() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    plant = owned_plant(user_id)
    repository.plants[plant.id] = plant
    repository.devices[DEVICE_ID] = claimed_device(DEVICE_ID, user_id)

    result = await SensorDeviceManagementService(repository).connect_plant_device(
        user_id, plant.id, DEVICE_ID
    )

    assert result == PlantSensorDeviceResponse(plant_id=plant.id, device_id=DEVICE_ID)
    assert repository.links[plant.id] == DEVICE_ID


async def test_connect_plant_device_auto_replaces_existing_device_link() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    old_plant = owned_plant(user_id)
    new_plant = owned_plant(user_id)
    repository.plants[old_plant.id] = old_plant
    repository.plants[new_plant.id] = new_plant
    repository.devices[DEVICE_ID] = claimed_device(DEVICE_ID, user_id)
    repository.links[old_plant.id] = DEVICE_ID

    await SensorDeviceManagementService(repository).connect_plant_device(
        user_id, new_plant.id, DEVICE_ID
    )

    assert old_plant.id not in repository.links
    assert repository.links[new_plant.id] == DEVICE_ID


async def test_connect_plant_device_auto_replaces_existing_plant_link() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    plant = owned_plant(user_id)
    repository.plants[plant.id] = plant
    repository.devices[DEVICE_ID] = claimed_device(DEVICE_ID, user_id)
    repository.devices[OTHER_DEVICE_ID] = claimed_device(OTHER_DEVICE_ID, user_id)
    repository.links[plant.id] = DEVICE_ID

    await SensorDeviceManagementService(repository).connect_plant_device(
        user_id, plant.id, OTHER_DEVICE_ID
    )

    assert repository.links[plant.id] == OTHER_DEVICE_ID


async def test_disconnect_plant_device_rejects_unowned_plant() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()

    with pytest.raises(AppError) as error:
        await SensorDeviceManagementService(repository).disconnect_plant_device(user_id, uuid4())

    assert error.value.code == "PLANT_NOT_FOUND"


async def test_disconnect_plant_device_removes_link() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    plant = owned_plant(user_id)
    repository.plants[plant.id] = plant
    repository.links[plant.id] = DEVICE_ID

    await SensorDeviceManagementService(repository).disconnect_plant_device(user_id, plant.id)

    assert plant.id not in repository.links


async def test_disconnect_plant_device_is_idempotent_without_existing_link() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    plant = owned_plant(user_id)
    repository.plants[plant.id] = plant

    await SensorDeviceManagementService(repository).disconnect_plant_device(user_id, plant.id)


async def test_release_device_rejects_unowned_device() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    repository.devices[DEVICE_ID] = claimed_device(DEVICE_ID, uuid4())

    with pytest.raises(AppError) as error:
        await SensorDeviceManagementService(repository).release_device(user_id, DEVICE_ID)

    assert error.value.code == "SENSOR_DEVICE_NOT_FOUND"
    assert error.value.status_code == 404


async def test_release_device_resets_ownership_and_removes_plant_link() -> None:
    repository = FakeSensorDeviceManagementRepository()
    user_id = uuid4()
    plant = owned_plant(user_id)
    device = claimed_device(DEVICE_ID, user_id)
    repository.plants[plant.id] = plant
    repository.devices[DEVICE_ID] = device
    repository.links[plant.id] = DEVICE_ID

    await SensorDeviceManagementService(repository).release_device(user_id, DEVICE_ID)

    assert device.status == SensorDeviceStatus.UNCLAIMED.value
    assert device.owner_user_id is None
    assert device.sensor_token_hash is None
    assert device.claimed_at is None
    assert plant.id not in repository.links


async def test_release_device_allows_reclaim_by_a_new_owner() -> None:
    """공장 초기화 후 재등록: 소유 해제된 기기는 다시 claim 대상이 될 수 있다."""
    repository = FakeSensorDeviceManagementRepository()
    previous_owner = uuid4()
    device = claimed_device(DEVICE_ID, previous_owner)
    repository.devices[DEVICE_ID] = device

    await SensorDeviceManagementService(repository).release_device(previous_owner, DEVICE_ID)

    assert device.status == SensorDeviceStatus.UNCLAIMED.value
    assert device.owner_user_id is None


def test_sensor_device_list_and_release_http_contract(monkeypatch) -> None:
    management_service = SimpleNamespace(
        list_devices=AsyncMock(
            return_value=SensorDeviceListResponse(
                items=[
                    SensorDeviceListItemResponse(
                        device_id=DEVICE_ID,
                        status=SensorDeviceStatus.CLAIMED,
                        last_seen_at=None,
                        plant_id=None,
                        lux=None,
                        soil_raw=None,
                        measured_at=None,
                    )
                ]
            )
        ),
        release_device=AsyncMock(return_value=None),
    )

    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=uuid4(), email=None, role=None, claims={}
    )
    app.dependency_overrides[get_database_session] = lambda: object()
    monkeypatch.setattr(sensor_api, "build_management_service", lambda _session: management_service)
    client = TestClient(app)

    listed = client.get("/api/v1/sensor-devices")
    assert listed.status_code == 200
    assert listed.json() == {
        "items": [
            {
                "deviceId": DEVICE_ID,
                "status": "CLAIMED",
                "lastSeenAt": None,
                "plantId": None,
                "lux": None,
                "soilRaw": None,
                "measuredAt": None,
            }
        ]
    }

    released = client.delete(f"/api/v1/sensor-devices/{DEVICE_ID}")
    assert released.status_code == 204


def test_plant_sensor_device_connect_and_disconnect_http_contract(monkeypatch) -> None:
    plant_id = uuid4()
    management_service = SimpleNamespace(
        connect_plant_device=AsyncMock(
            return_value=PlantSensorDeviceResponse(plant_id=plant_id, device_id=DEVICE_ID)
        ),
        disconnect_plant_device=AsyncMock(return_value=None),
    )

    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=uuid4(), email=None, role=None, claims={}
    )
    app.dependency_overrides[get_database_session] = lambda: object()
    monkeypatch.setattr(
        plants_api, "build_sensor_management_service", lambda _session: management_service
    )
    client = TestClient(app)

    connected = client.put(
        f"/api/v1/plants/{plant_id}/sensor-device", json={"deviceId": DEVICE_ID}
    )
    assert connected.status_code == 200
    assert connected.json() == {"plantId": str(plant_id), "deviceId": DEVICE_ID}

    disconnected = client.delete(f"/api/v1/plants/{plant_id}/sensor-device")
    assert disconnected.status_code == 204
