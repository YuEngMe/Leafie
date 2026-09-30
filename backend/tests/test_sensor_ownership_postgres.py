"""Opt-in PostgreSQL checks for sensor claim/unclaim ownership races (leafie_care_test)."""

import asyncio
from uuid import UUID, uuid4

import pytest
from sqlalchemy import delete, select

from app.core.errors import AppError
from app.db.base import AUTH_USERS_TABLE
from app.models.sensor import PlantSensorDevice, SensorDevice
from app.services.sensor import (
    SensorDeviceClaimService,
    SensorDeviceService,
    SQLAlchemySensorDeviceClaimRepository,
    SQLAlchemySensorDeviceRepository,
    hash_token,
)
from app.services.sensor_management import (
    SensorDeviceManagementService,
    SQLAlchemySensorDeviceManagementRepository,
)
from tests.test_care_postgres import care_db  # noqa: F401

DEVICE_ID = "AB12CD34EF56"


@pytest.fixture
async def sensor_db(care_db):  # noqa: F811
    db, user_a, plant_id = care_db
    user_b = uuid4()
    async with db.session_context() as session:
        await session.execute(AUTH_USERS_TABLE.insert().values(id=user_b))
        await SensorDeviceService(SQLAlchemySensorDeviceRepository(session)).register_device(
            DEVICE_ID
        )
    try:
        yield db, user_a, user_b, plant_id
    finally:
        async with db.engine.begin() as connection:
            await connection.execute(delete(SensorDevice).where(SensorDevice.id == DEVICE_ID))
            await connection.execute(
                delete(AUTH_USERS_TABLE).where(AUTH_USERS_TABLE.c.id == user_b)
            )


async def claim(db, user_id: UUID) -> tuple[str, str]:
    async with db.session_context() as session:
        service = SensorDeviceClaimService(SQLAlchemySensorDeviceClaimRepository(session))
        claim_token = (await service.create_claim(user_id, DEVICE_ID)).claim_token
    async with db.session_context() as session:
        service = SensorDeviceClaimService(SQLAlchemySensorDeviceClaimRepository(session))
        device_token = (await service.complete_claim(claim_token, DEVICE_ID)).device_token
    return claim_token, device_token


async def complete(db, claim_token: str):
    async with db.session_context() as session:
        service = SensorDeviceClaimService(SQLAlchemySensorDeviceClaimRepository(session))
        return await service.complete_claim(claim_token, DEVICE_ID)


async def release(db, user_id: UUID) -> None:
    async with db.session_context() as session:
        service = SensorDeviceManagementService(SQLAlchemySensorDeviceManagementRepository(session))
        await service.release_device(user_id, DEVICE_ID)


async def device_row(db) -> SensorDevice:
    async with db.session_context() as session:
        return await session.scalar(
            select(SensorDevice)
            .where(SensorDevice.id == DEVICE_ID)
            .execution_options(populate_existing=True)
        )


async def test_stale_claim_rejected_after_unclaim_and_other_user_reclaim(sensor_db):
    db, user_a, user_b, _ = sensor_db
    claim_a, token_a = await claim(db, user_a)
    await release(db, user_a)

    with pytest.raises(AppError) as error:
        await complete(db, claim_a)
    assert error.value.status_code == 410
    assert (await device_row(db)).sensor_token_hash is None

    _, token_b = await claim(db, user_b)
    with pytest.raises(AppError) as error:
        await complete(db, claim_a)
    assert error.value.status_code == 410
    device = await device_row(db)
    assert device.owner_user_id == user_b
    assert device.sensor_token_hash == hash_token(token_b)
    assert hash_token(token_a) != device.sensor_token_hash


async def test_blocked_release_does_not_wipe_new_owner(sensor_db):
    db, user_a, user_b, _ = sensor_db
    await claim(db, user_a)

    async with db.session_context() as first:
        first_service = SensorDeviceManagementService(
            SQLAlchemySensorDeviceManagementRepository(first)
        )
        device = await SQLAlchemySensorDeviceManagementRepository(first).get_owned_device(
            user_a, DEVICE_ID
        )
        assert device is not None
        # 두 번째 해제 요청은 기기 잠금에서 대기해야 한다.
        stale = asyncio.create_task(release(db, user_a))
        await asyncio.sleep(0.5)
        assert not stale.done()
        await first_service._repository.release_device(device, user_a)
    with pytest.raises(AppError) as error:
        await stale
    assert error.value.status_code == 404

    _, token_b = await claim(db, user_b)
    device = await device_row(db)
    assert device.owner_user_id == user_b
    assert device.sensor_token_hash == hash_token(token_b)


async def test_connect_waits_for_release_and_is_rejected(sensor_db):
    db, user_a, _, plant_id = sensor_db
    await claim(db, user_a)

    async with db.session_context() as first:
        repo = SQLAlchemySensorDeviceManagementRepository(first)
        device = await repo.get_owned_device(user_a, DEVICE_ID)
        assert device is not None

        async def connect():
            async with db.session_context() as session:
                await SensorDeviceManagementService(
                    SQLAlchemySensorDeviceManagementRepository(session)
                ).connect_plant_device(user_a, plant_id, DEVICE_ID)

        racing = asyncio.create_task(connect())
        await asyncio.sleep(0.5)
        assert not racing.done()
        await repo.release_device(device, user_a)
    with pytest.raises(AppError) as error:
        await racing
    assert error.value.status_code == 404
    async with db.session_context() as session:
        assert await session.scalar(select(PlantSensorDevice)) is None
