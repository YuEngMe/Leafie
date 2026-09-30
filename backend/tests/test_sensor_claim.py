from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_current_user, get_database_session
from app.api.v1 import sensor as sensor_api
from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.enums import SensorDeviceClaimStatus, SensorDeviceStatus
from app.models.sensor import SensorDevice, SensorDeviceClaim
from app.schemas.sensor import (
    SensorDeviceClaimCompleteResponse,
    SensorDeviceClaimCreateResponse,
    SensorDeviceClaimStatusResponse,
)
from app.services.sensor import CLAIM_TTL, SensorDeviceClaimService, hash_token

DEVICE_ID = "D40592E7D168"


class FakeSensorDeviceClaimRepository:
    def __init__(self) -> None:
        self.devices: dict[str, SensorDevice] = {}
        self.claims: dict[UUID, SensorDeviceClaim] = {}
        self.cancelled: list[UUID] = []
        self.add_claim_calls = 0
        self.force_race_once = False

    async def get_device(self, device_id: str) -> SensorDevice | None:
        return self.devices.get(device_id)

    async def get_pending_claim(self, device_id: str) -> SensorDeviceClaim | None:
        for claim in self.claims.values():
            if (
                claim.device_id == device_id
                and claim.status == SensorDeviceClaimStatus.PENDING.value
            ):
                return claim
        return None

    async def cancel_claim(self, claim: SensorDeviceClaim) -> None:
        claim.status = SensorDeviceClaimStatus.CANCELLED.value
        self.cancelled.append(claim.id)

    async def add_claim(self, claim: SensorDeviceClaim) -> None:
        self.add_claim_calls += 1
        if claim.id is None:
            claim.id = uuid4()
        self.claims[claim.id] = claim

    async def get_claim_by_token_hash(self, token_hash: str) -> SensorDeviceClaim | None:
        for claim in self.claims.values():
            if claim.claim_token_hash == token_hash:
                return claim
        return None

    async def try_complete_claim(self, claim_id: UUID, completed_at: datetime) -> bool:
        claim = self.claims[claim_id]
        if self.force_race_once:
            # 실제 Postgres에서는 먼저 커밋된 다른 트랜잭션이 이 조건부 UPDATE로 이미
            # 이겼을 때의 모습이다: claim/device 둘 다 그 트랜잭션 안에서 함께 바뀐
            # 상태로 보인다(같은 커밋을 loser가 뒤늦게 관찰).
            self.force_race_once = False
            claim.status = SensorDeviceClaimStatus.COMPLETED.value
            claim.completed_at = completed_at
            device = self.devices[claim.device_id]
            device.status = SensorDeviceStatus.CLAIMED.value
            device.owner_user_id = claim.user_id
            device.sensor_token_hash = hash_token("concurrent-winner-token")
            device.claimed_at = completed_at
            return False
        if claim.status != SensorDeviceClaimStatus.PENDING.value:
            return False
        claim.status = SensorDeviceClaimStatus.COMPLETED.value
        claim.completed_at = completed_at
        return True

    async def claim_device(
        self, device_id: str, user_id: UUID, token_hash: str, claimed_at: datetime
    ) -> bool:
        device = self.devices[device_id]
        if device.status != SensorDeviceStatus.UNCLAIMED.value:
            return False
        device.status = SensorDeviceStatus.CLAIMED.value
        device.owner_user_id = user_id
        device.sensor_token_hash = token_hash
        device.claimed_at = claimed_at
        return True

    async def rotate_device_token(
        self, claim_id: UUID, device_id: str, user_id: UUID, token_hash: str
    ) -> bool:
        device = self.devices[device_id]
        if (
            device.owner_user_id != user_id
            or self.claims[claim_id].status != SensorDeviceClaimStatus.COMPLETED.value
        ):
            return False
        device.sensor_token_hash = token_hash
        return True


def unclaimed_device(device_id: str = DEVICE_ID) -> SensorDevice:
    return SensorDevice(id=device_id, status=SensorDeviceStatus.UNCLAIMED.value)


def pending_claim(
    *,
    device_id: str = DEVICE_ID,
    user_id: UUID,
    claim_token: str,
    now: datetime,
    ttl: timedelta = CLAIM_TTL,
) -> SensorDeviceClaim:
    return SensorDeviceClaim(
        id=uuid4(),
        device_id=device_id,
        user_id=user_id,
        claim_token_hash=hash_token(claim_token),
        status=SensorDeviceClaimStatus.PENDING.value,
        expires_at=now + ttl,
        created_at=now,
    )


async def test_create_claim_rejects_unregistered_device() -> None:
    repository = FakeSensorDeviceClaimRepository()

    with pytest.raises(AppError) as error:
        await SensorDeviceClaimService(repository).create_claim(uuid4(), DEVICE_ID)

    assert error.value.code == "SENSOR_DEVICE_NOT_FOUND"
    assert error.value.status_code == 404


async def test_create_claim_rejects_already_claimed_device() -> None:
    repository = FakeSensorDeviceClaimRepository()
    repository.devices[DEVICE_ID] = SensorDevice(
        id=DEVICE_ID,
        status=SensorDeviceStatus.CLAIMED.value,
        owner_user_id=uuid4(),
        sensor_token_hash="a" * 64,
    )

    with pytest.raises(AppError) as error:
        await SensorDeviceClaimService(repository).create_claim(uuid4(), DEVICE_ID)

    assert error.value.code == "SENSOR_DEVICE_ALREADY_CLAIMED"
    assert error.value.status_code == 409


async def test_create_claim_cancels_existing_pending_and_issues_new_token() -> None:
    repository = FakeSensorDeviceClaimRepository()
    repository.devices[DEVICE_ID] = unclaimed_device()
    now = datetime.now(UTC)
    stale = pending_claim(
        user_id=uuid4(), claim_token="stale-token", now=now - timedelta(minutes=1)
    )
    repository.claims[stale.id] = stale

    result = await SensorDeviceClaimService(repository).create_claim(uuid4(), DEVICE_ID)

    assert stale.status == SensorDeviceClaimStatus.CANCELLED.value
    assert repository.cancelled == [stale.id]
    pending = [
        c for c in repository.claims.values() if c.status == SensorDeviceClaimStatus.PENDING.value
    ]
    assert len(pending) == 1
    assert pending[0].claim_token_hash == hash_token(result.claim_token)


async def test_complete_claim_rejects_unknown_token() -> None:
    repository = FakeSensorDeviceClaimRepository()

    with pytest.raises(AppError) as error:
        await SensorDeviceClaimService(repository).complete_claim("nope", DEVICE_ID)

    assert error.value.code == "CLAIM_NOT_FOUND"
    assert error.value.status_code == 404


async def test_complete_claim_rejects_device_mismatch() -> None:
    repository = FakeSensorDeviceClaimRepository()
    user_id = uuid4()
    now = datetime.now(UTC)
    claim = pending_claim(user_id=user_id, claim_token="tok", now=now)
    repository.devices[DEVICE_ID] = unclaimed_device()
    repository.claims[claim.id] = claim

    with pytest.raises(AppError) as error:
        await SensorDeviceClaimService(repository).complete_claim("tok", "AAAAAAAAAAAA")

    assert error.value.code == "CLAIM_DEVICE_MISMATCH"
    assert error.value.status_code == 409


async def test_complete_claim_rejects_expired_claim() -> None:
    repository = FakeSensorDeviceClaimRepository()
    user_id = uuid4()
    now = datetime.now(UTC)
    claim = pending_claim(
        user_id=user_id, claim_token="tok", now=now - CLAIM_TTL - timedelta(seconds=1)
    )
    repository.devices[DEVICE_ID] = unclaimed_device()
    repository.claims[claim.id] = claim

    with pytest.raises(AppError) as error:
        await SensorDeviceClaimService(repository).complete_claim("tok", DEVICE_ID)

    assert error.value.code == "CLAIM_EXPIRED"
    assert error.value.status_code == 410


async def test_complete_claim_succeeds_and_claims_device() -> None:
    repository = FakeSensorDeviceClaimRepository()
    user_id = uuid4()
    now = datetime.now(UTC)
    claim = pending_claim(user_id=user_id, claim_token="tok", now=now)
    repository.devices[DEVICE_ID] = unclaimed_device()
    repository.claims[claim.id] = claim

    result = await SensorDeviceClaimService(repository).complete_claim("tok", DEVICE_ID)

    device = repository.devices[DEVICE_ID]
    assert device.status == SensorDeviceStatus.CLAIMED.value
    assert device.owner_user_id == user_id
    assert device.sensor_token_hash == hash_token(result.device_token)
    assert claim.status == SensorDeviceClaimStatus.COMPLETED.value


async def test_complete_claim_retry_within_window_reissues_new_token() -> None:
    repository = FakeSensorDeviceClaimRepository()
    user_id = uuid4()
    now = datetime.now(UTC)
    claim = pending_claim(user_id=user_id, claim_token="tok", now=now)
    repository.devices[DEVICE_ID] = unclaimed_device()
    repository.claims[claim.id] = claim
    service = SensorDeviceClaimService(repository)

    first = await service.complete_claim("tok", DEVICE_ID)
    second = await service.complete_claim("tok", DEVICE_ID)

    assert first.device_token != second.device_token
    device = repository.devices[DEVICE_ID]
    assert device.sensor_token_hash == hash_token(second.device_token)
    assert device.owner_user_id == user_id


async def test_complete_claim_retry_after_window_is_expired() -> None:
    repository = FakeSensorDeviceClaimRepository()
    user_id = uuid4()
    now = datetime.now(UTC)
    claim = pending_claim(user_id=user_id, claim_token="tok", now=now)
    repository.devices[DEVICE_ID] = unclaimed_device()
    repository.claims[claim.id] = claim
    service = SensorDeviceClaimService(repository)
    await service.complete_claim("tok", DEVICE_ID)
    claim.expires_at = now - timedelta(seconds=1)

    with pytest.raises(AppError) as error:
        await service.complete_claim("tok", DEVICE_ID)

    assert error.value.code == "CLAIM_EXPIRED"
    assert error.value.status_code == 410


async def test_complete_claim_concurrent_calls_both_return_a_valid_token() -> None:
    repository = FakeSensorDeviceClaimRepository()
    user_id = uuid4()
    now = datetime.now(UTC)
    claim = pending_claim(user_id=user_id, claim_token="tok", now=now)
    repository.devices[DEVICE_ID] = unclaimed_device()
    repository.claims[claim.id] = claim
    service = SensorDeviceClaimService(repository)
    repository.force_race_once = True

    result = await service.complete_claim("tok", DEVICE_ID)

    device = repository.devices[DEVICE_ID]
    assert device.status == SensorDeviceStatus.CLAIMED.value
    assert device.sensor_token_hash == hash_token(result.device_token)
    assert claim.status == SensorDeviceClaimStatus.COMPLETED.value


async def test_get_status_hides_other_users_claim() -> None:
    repository = FakeSensorDeviceClaimRepository()
    now = datetime.now(UTC)
    claim = pending_claim(user_id=uuid4(), claim_token="tok", now=now)
    repository.claims[claim.id] = claim

    with pytest.raises(AppError) as error:
        await SensorDeviceClaimService(repository).get_status(uuid4(), "tok")

    assert error.value.code == "CLAIM_NOT_FOUND"
    assert error.value.status_code == 404


async def test_get_status_reports_expired_without_mutating_stored_status() -> None:
    repository = FakeSensorDeviceClaimRepository()
    user_id = uuid4()
    now = datetime.now(UTC)
    claim = pending_claim(
        user_id=user_id, claim_token="tok", now=now - CLAIM_TTL - timedelta(seconds=1)
    )
    repository.claims[claim.id] = claim

    result = await SensorDeviceClaimService(repository).get_status(user_id, "tok")

    assert result.status == SensorDeviceClaimStatus.EXPIRED
    assert claim.status == SensorDeviceClaimStatus.PENDING.value


async def test_get_status_reports_completed() -> None:
    repository = FakeSensorDeviceClaimRepository()
    user_id = uuid4()
    now = datetime.now(UTC)
    claim = pending_claim(user_id=user_id, claim_token="tok", now=now)
    repository.devices[DEVICE_ID] = unclaimed_device()
    repository.claims[claim.id] = claim
    await SensorDeviceClaimService(repository).complete_claim("tok", DEVICE_ID)

    result = await SensorDeviceClaimService(repository).get_status(user_id, "tok")

    assert result.status == SensorDeviceClaimStatus.COMPLETED


def test_claim_endpoints_http_contract(monkeypatch) -> None:
    claim_service = SimpleNamespace(
        create_claim=AsyncMock(
            return_value=SensorDeviceClaimCreateResponse(claim_token="plaintext-claim-token")
        ),
        complete_claim=AsyncMock(
            return_value=SensorDeviceClaimCompleteResponse(device_token="plaintext-device-token")
        ),
        get_status=AsyncMock(
            return_value=SensorDeviceClaimStatusResponse(status=SensorDeviceClaimStatus.PENDING)
        ),
    )

    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=uuid4(), email=None, role=None, claims={}
    )
    app.dependency_overrides[get_database_session] = lambda: object()
    monkeypatch.setattr(sensor_api, "build_claim_service", lambda _session: claim_service)
    client = TestClient(app)

    created = client.post(f"/api/v1/sensor-devices/{DEVICE_ID}/claims")
    assert created.status_code == 201
    assert created.json() == {"claimToken": "plaintext-claim-token"}

    completed = client.post(
        "/api/v1/sensor-device-claims/tok/complete",
        json={"deviceId": DEVICE_ID},
    )
    assert completed.status_code == 200
    assert completed.json() == {"deviceToken": "plaintext-device-token"}

    status_response = client.get("/api/v1/sensor-device-claims/tok")
    assert status_response.status_code == 200
    assert status_response.json() == {"status": "PENDING"}


def test_complete_endpoint_requires_no_user_auth(monkeypatch) -> None:
    claim_service = SimpleNamespace(
        complete_claim=AsyncMock(
            return_value=SensorDeviceClaimCompleteResponse(device_token="token")
        )
    )

    app = create_app()
    app.dependency_overrides[get_database_session] = lambda: object()
    monkeypatch.setattr(sensor_api, "build_claim_service", lambda _session: claim_service)
    client = TestClient(app)

    response = client.post(
        "/api/v1/sensor-device-claims/tok/complete",
        json={"deviceId": DEVICE_ID},
    )

    assert response.status_code == 200