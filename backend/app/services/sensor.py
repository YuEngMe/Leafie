import hashlib
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Protocol
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.enums import SensorDeviceClaimStatus, SensorDeviceStatus
from app.models.sensor import SensorDevice, SensorDeviceClaim
from app.schemas.sensor import (
    SensorDeviceClaimCompleteResponse,
    SensorDeviceClaimCreateResponse,
    SensorDeviceClaimStatusResponse,
    SensorDeviceResponse,
)

CLAIM_TTL = timedelta(minutes=5)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


@dataclass(frozen=True, slots=True)
class SensorDeviceRegistrationResult:
    response: SensorDeviceResponse
    created: bool


class SensorDeviceRepository(Protocol):
    async def get(self, device_id: str) -> SensorDevice | None: ...

    async def add(self, device: SensorDevice) -> tuple[SensorDevice, bool]: ...


class SQLAlchemySensorDeviceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, device_id: str) -> SensorDevice | None:
        return await self._session.scalar(select(SensorDevice).where(SensorDevice.id == device_id))

    async def add(self, device: SensorDevice) -> tuple[SensorDevice, bool]:
        try:
            async with self._session.begin_nested():
                self._session.add(device)
                await self._session.flush()
            return device, True
        except IntegrityError:
            existing = await self._session.scalar(
                select(SensorDevice).where(SensorDevice.id == device.id)
            )
            if existing is None:
                raise
            return existing, False


class SensorDeviceService:
    def __init__(self, repository: SensorDeviceRepository) -> None:
        self._repository = repository

    async def register_device(self, device_id: str) -> SensorDeviceRegistrationResult:
        existing = await self._repository.get(device_id)
        if existing is not None:
            return SensorDeviceRegistrationResult(response=_to_response(existing), created=False)

        device = SensorDevice(id=device_id, status=SensorDeviceStatus.UNCLAIMED.value)
        stored, created = await self._repository.add(device)
        return SensorDeviceRegistrationResult(response=_to_response(stored), created=created)


def _to_response(device: SensorDevice) -> SensorDeviceResponse:
    return SensorDeviceResponse(device_id=device.id, status=SensorDeviceStatus(device.status))


class SensorDeviceClaimRepository(Protocol):
    async def get_device(self, device_id: str) -> SensorDevice | None: ...

    async def get_pending_claim(self, device_id: str) -> SensorDeviceClaim | None: ...

    async def cancel_claim(self, claim: SensorDeviceClaim) -> None: ...

    async def add_claim(self, claim: SensorDeviceClaim) -> None: ...

    async def get_claim_by_token_hash(self, token_hash: str) -> SensorDeviceClaim | None: ...

    async def try_complete_claim(self, claim_id: UUID, completed_at: datetime) -> bool: ...

    async def claim_device(
        self, device_id: str, user_id: UUID, token_hash: str, claimed_at: datetime
    ) -> bool: ...

    async def rotate_device_token(
        self, claim_id: UUID, device_id: str, user_id: UUID, token_hash: str
    ) -> bool: ...


class SQLAlchemySensorDeviceClaimRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_device(self, device_id: str) -> SensorDevice | None:
        return await self._session.scalar(select(SensorDevice).where(SensorDevice.id == device_id))

    async def get_pending_claim(self, device_id: str) -> SensorDeviceClaim | None:
        return await self._session.scalar(
            select(SensorDeviceClaim).where(
                SensorDeviceClaim.device_id == device_id,
                SensorDeviceClaim.status == SensorDeviceClaimStatus.PENDING.value,
            )
        )

    async def cancel_claim(self, claim: SensorDeviceClaim) -> None:
        claim.status = SensorDeviceClaimStatus.CANCELLED.value
        # 같은 플러시 안에서 새 PENDING claim을 넣기 전에 반드시 반영되어야 한다
        # (기기당 PENDING 하나 partial unique index).
        await self._session.flush()

    async def add_claim(self, claim: SensorDeviceClaim) -> None:
        try:
            async with self._session.begin_nested():
                self._session.add(claim)
                await self._session.flush()
        except IntegrityError as error:
            raise AppError(
                code="SENSOR_DEVICE_CLAIM_CONFLICT",
                message="요청이 겹쳤습니다. 다시 시도해 주세요.",
                status_code=409,
            ) from error

    async def get_claim_by_token_hash(self, token_hash: str) -> SensorDeviceClaim | None:
        return await self._session.scalar(
            select(SensorDeviceClaim).where(SensorDeviceClaim.claim_token_hash == token_hash)
        )

    async def try_complete_claim(self, claim_id: UUID, completed_at: datetime) -> bool:
        result = await self._session.execute(
            update(SensorDeviceClaim)
            .where(
                SensorDeviceClaim.id == claim_id,
                SensorDeviceClaim.status == SensorDeviceClaimStatus.PENDING.value,
            )
            .values(status=SensorDeviceClaimStatus.COMPLETED.value, completed_at=completed_at)
        )
        return result.rowcount == 1

    async def claim_device(
        self, device_id: str, user_id: UUID, token_hash: str, claimed_at: datetime
    ) -> bool:
        result = await self._session.execute(
            update(SensorDevice)
            .where(
                SensorDevice.id == device_id,
                SensorDevice.status == SensorDeviceStatus.UNCLAIMED.value,
            )
            .values(
                status=SensorDeviceStatus.CLAIMED.value,
                owner_user_id=user_id,
                sensor_token_hash=token_hash,
                claimed_at=claimed_at,
            )
        )
        return result.rowcount == 1

    async def rotate_device_token(
        self, claim_id: UUID, device_id: str, user_id: UUID, token_hash: str
    ) -> bool:
        # 기기 행을 먼저 잠근 뒤 별도 문장으로 조건을 검사한다(READ COMMITTED에서는 잠금 이후
        # 문장이 최신 커밋을 본다). 해제/재claim된 기기의 오래된 claim은 여기서 걸러진다.
        await self._session.execute(
            select(SensorDevice.id).where(SensorDevice.id == device_id).with_for_update()
        )
        result = await self._session.execute(
            update(SensorDevice)
            .where(
                SensorDevice.id == device_id,
                SensorDevice.owner_user_id == user_id,
                SensorDevice.status == SensorDeviceStatus.CLAIMED.value,
                select(SensorDeviceClaim.id)
                .where(
                    SensorDeviceClaim.id == claim_id,
                    SensorDeviceClaim.status == SensorDeviceClaimStatus.COMPLETED.value,
                )
                .exists(),
            )
            .values(sensor_token_hash=token_hash)
        )
        return result.rowcount == 1


class SensorDeviceClaimService:
    def __init__(self, repository: SensorDeviceClaimRepository) -> None:
        self._repository = repository

    async def create_claim(self, user_id: UUID, device_id: str) -> SensorDeviceClaimCreateResponse:
        device = await self._repository.get_device(device_id)
        if device is None:
            raise AppError(
                code="SENSOR_DEVICE_NOT_FOUND", message="기기를 찾을 수 없습니다.", status_code=404
            )
        if device.status != SensorDeviceStatus.UNCLAIMED:
            raise AppError(
                code="SENSOR_DEVICE_ALREADY_CLAIMED",
                message="이미 등록된 기기입니다.",
                status_code=409,
            )

        existing_pending = await self._repository.get_pending_claim(device_id)
        if existing_pending is not None:
            await self._repository.cancel_claim(existing_pending)

        now = datetime.now(UTC)
        claim_token = secrets.token_hex(32)
        claim = SensorDeviceClaim(
            device_id=device_id,
            user_id=user_id,
            claim_token_hash=hash_token(claim_token),
            status=SensorDeviceClaimStatus.PENDING.value,
            expires_at=now + CLAIM_TTL,
            created_at=now,
        )
        await self._repository.add_claim(claim)
        return SensorDeviceClaimCreateResponse(claim_token=claim_token)

    async def complete_claim(
        self, claim_token: str, device_id: str
    ) -> SensorDeviceClaimCompleteResponse:
        claim = await self._repository.get_claim_by_token_hash(hash_token(claim_token))
        if claim is None:
            raise AppError(
                code="CLAIM_NOT_FOUND", message="claim을 찾을 수 없습니다.", status_code=404
            )
        if claim.device_id != device_id:
            raise AppError(
                code="CLAIM_DEVICE_MISMATCH",
                message="deviceId가 claim과 일치하지 않습니다.",
                status_code=409,
            )

        now = datetime.now(UTC)
        if now >= claim.expires_at or claim.status == SensorDeviceClaimStatus.CANCELLED:
            raise AppError(code="CLAIM_EXPIRED", message="claim이 만료되었습니다.", status_code=410)

        if claim.status == SensorDeviceClaimStatus.PENDING:
            won = await self._repository.try_complete_claim(claim.id, now)
            if won:
                device_token = secrets.token_hex(32)
                claimed = await self._repository.claim_device(
                    claim.device_id, claim.user_id, hash_token(device_token), now
                )
                if not claimed:
                    raise AppError(
                        code="CLAIM_DEVICE_STATE_CONFLICT",
                        message="기기 상태가 예상과 다릅니다.",
                        status_code=409,
                    )
                return SensorDeviceClaimCompleteResponse(device_token=device_token)
            # 동시에 다른 요청이 먼저 완료 처리했다: 재조회해 재발급 경로로 진행한다.
            claim = await self._repository.get_claim_by_token_hash(hash_token(claim_token))
            if claim is None:
                raise AppError(
                    code="CLAIM_NOT_FOUND", message="claim을 찾을 수 없습니다.", status_code=404
                )

        if claim.status == SensorDeviceClaimStatus.COMPLETED:
            device_token = secrets.token_hex(32)
            rotated = await self._repository.rotate_device_token(
                claim.id, claim.device_id, claim.user_id, hash_token(device_token)
            )
            if not rotated:
                raise AppError(
                    code="CLAIM_EXPIRED", message="claim이 만료되었습니다.", status_code=410
                )
            return SensorDeviceClaimCompleteResponse(device_token=device_token)

        raise AppError(code="CLAIM_EXPIRED", message="claim이 만료되었습니다.", status_code=410)

    async def get_status(self, user_id: UUID, claim_token: str) -> SensorDeviceClaimStatusResponse:
        claim = await self._repository.get_claim_by_token_hash(hash_token(claim_token))
        if claim is None or claim.user_id != user_id:
            raise AppError(
                code="CLAIM_NOT_FOUND", message="claim을 찾을 수 없습니다.", status_code=404
            )

        status = SensorDeviceClaimStatus(claim.status)
        now = datetime.now(UTC)
        if status == SensorDeviceClaimStatus.PENDING and now >= claim.expires_at:
            status = SensorDeviceClaimStatus.EXPIRED
        return SensorDeviceClaimStatusResponse(status=status)
