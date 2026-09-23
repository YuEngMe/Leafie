"""Real PostgreSQL checks; opt in only with a disposable local leafie_sensor_test DB."""

import os
import runpy
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import delete, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError, IntegrityError

from app.core.config import Settings
from app.db.base import AUTH_USERS_TABLE, Base
from app.db.session import Database
from app.models.plant import Plant, SpeciesCareGuide
from app.models.user import UserProfile

MIGRATION = Path(__file__).parents[1] / "alembic/versions/cd31c92afd23_add_sensor_readings.py"
SENSOR_TABLES = ("devices", "device_claims", "plant_devices", "sensor_readings")
DEVICE_ID = "D40592E7D168"
OTHER_DEVICE_ID = "AAAAAAAAAAAA"
INSERT_READING = text(
    "INSERT INTO sensor_readings "
    "(device_id, sqs_message_id, measured_at, received_at, lux, soil_raw) "
    "VALUES (:device_id, :message_id, :measured_at, :received_at, :lux, :soil_raw) "
    # 충돌 대상을 지정하면 그 컬럼의 SELECT 권한이 필요하다. sensor_ingest는 INSERT만 갖는다.
    "ON CONFLICT DO NOTHING"
)


def token_hash(n: int) -> str:
    return f"{n:064x}"


def reading(**overrides):
    values = {
        "device_id": DEVICE_ID,
        "message_id": uuid4(),
        "measured_at": datetime(2026, 9, 24, 1, 30, tzinfo=UTC),
        "received_at": datetime(2026, 9, 24, 1, 30, 5, tzinfo=UTC),
        "lux": 123.4,
        "soil_raw": 3900,
    }
    return values | overrides


def constraint_names(table_name: str) -> set[str]:
    return {c.name for c in Base.metadata.tables[table_name].constraints if c.name}


def test_sensor_models_match_migration_contract() -> None:
    tables = Base.metadata.tables

    assert {c.name for c in tables["devices"].columns} == {
        "id",
        "owner_user_id",
        "device_token_hash",
        "status",
        "firmware_version",
        "claimed_at",
        "last_seen_at",
        "created_at",
        "updated_at",
    }
    assert {c.name for c in tables["device_claims"].columns} == {
        "id",
        "device_id",
        "user_id",
        "claim_token_hash",
        "status",
        "expires_at",
        "created_at",
        "completed_at",
    }
    assert {c.name for c in tables["plant_devices"].columns} == {
        "device_id",
        "plant_id",
        "created_at",
    }
    assert {c.name for c in tables["sensor_readings"].columns} == {
        "id",
        "device_id",
        "sqs_message_id",
        "measured_at",
        "received_at",
        "lux",
        "soil_raw",
    }
    # claim 전에는 소유자가 없다 (AGENTS.md 17번).
    assert tables["devices"].columns["owner_user_id"].nullable is True
    # 센서 읽기 실패/시각 동기화 전 값은 null로 들어온다.
    for column in ("measured_at", "lux", "soil_raw"):
        assert tables["sensor_readings"].columns[column].nullable is True
    assert tables["sensor_readings"].columns["received_at"].nullable is False
    assert tables["sensor_readings"].columns["sqs_message_id"].unique is True
    assert {"ck_devices_claimed_state", "ck_devices_status"} <= constraint_names("devices")


@pytest.fixture
async def db():
    url = os.environ.get("SENSOR_TEST_DATABASE_URL")
    if not url:
        pytest.skip("Set SENSOR_TEST_DATABASE_URL to a disposable local PostgreSQL database")
    parsed = make_url(url)
    if parsed.host not in ("127.0.0.1", "localhost") or parsed.database != "leafie_sensor_test":
        pytest.fail("Sensor tests require a disposable localhost/leafie_sensor_test database")
    database = Database(Settings(_env_file=None, database_url=url))
    async with database.engine.begin() as connection:
        await connection.execute(text("CREATE SCHEMA IF NOT EXISTS auth"))
        for role in ("anon", "authenticated"):
            await connection.execute(
                text(
                    f"DO $$ BEGIN CREATE ROLE {role}; "
                    "EXCEPTION WHEN duplicate_object THEN NULL; END $$"
                )
            )
        await connection.run_sync(Base.metadata.create_all)
        # 실제 적용 결과(RLS, 역할, 권한)를 검증하려고 migration을 한 번 다시 적용한다.
        migration = runpy.run_path(str(MIGRATION))

        def rerun(sync_connection):
            from alembic.migration import MigrationContext
            from alembic.operations import Operations

            with Operations.context(MigrationContext.configure(sync_connection)):
                migration["downgrade"]()
                migration["upgrade"]()

        await connection.run_sync(rerun)
    try:
        yield database
    finally:
        async with database.engine.begin() as connection:
            await connection.execute(delete(AUTH_USERS_TABLE))
            await connection.execute(text("DELETE FROM devices"))
            await connection.execute(delete(SpeciesCareGuide))
        await database.close()


async def run(db, sql: str, **params):
    async with db.engine.begin() as connection:
        return await connection.execute(text(sql), params)


async def rejected(db, sql: str, **params):
    with pytest.raises(IntegrityError):
        await run(db, sql, **params)


async def seed_user(db):
    user_id = uuid4()
    async with db.session_context() as session:
        await session.execute(AUTH_USERS_TABLE.insert().values(id=user_id))
        session.add(UserProfile(user_id=user_id, nickname="집사"))
    return user_id


async def seed_plant(db, user_id):
    plant_id, guide_id = uuid4(), str(uuid4())
    async with db.session_context() as session:
        session.add(
            SpeciesCareGuide(species_reference_id=guide_id, display_name="바질", category="HERB")
        )
        await session.flush()
        session.add(
            Plant(
                id=plant_id,
                user_id=user_id,
                species_reference_id=guide_id,
                nickname="새싹이",
                client_registration_id=uuid4(),
                registration_request_hash="a" * 64,
                species_selection_method="SEARCH",
                started_on=date(2026, 1, 1),
                place_name="집",
                personality_type="INTROVERTED",
                body_id="body_circle",
                color_id="color_green",
                hair_id="leaf",
                expression_id="expression_default",
            )
        )
    return plant_id


INSERT_CLAIMED = (
    "INSERT INTO devices (id, owner_user_id, device_token_hash, status, claimed_at) "
    "VALUES (:id, :owner, :hash, 'CLAIMED', now())"
)


async def seed_claimed_device(db, device_id=DEVICE_ID, n=1):
    user_id = await seed_user(db)
    await run(db, INSERT_CLAIMED, id=device_id, owner=user_id, hash=token_hash(n))
    return user_id


async def insert_as_ingest(db, values=None):
    """Lambda가 쓰는 sensor_ingest 역할로 실행한다."""
    async with db.engine.connect() as connection:
        transaction = await connection.begin()
        await connection.execute(text("SET LOCAL ROLE sensor_ingest"))
        result = await connection.execute(INSERT_READING, values or reading())
        await transaction.commit()
        return result.rowcount


async def count(db, table: str) -> int:
    async with db.engine.connect() as connection:
        return await connection.scalar(text(f"SELECT count(*) FROM {table}"))


# ---- 권한 ----


async def test_tables_have_rls_and_are_hidden_from_app_roles(db):
    async with db.engine.connect() as connection:
        for table in SENSOR_TABLES:
            assert await connection.scalar(
                text("SELECT relrowsecurity FROM pg_class WHERE oid = CAST(:t AS regclass)"),
                {"t": f"public.{table}"},
            )
            for role in ("anon", "authenticated"):
                assert not await connection.scalar(
                    text("SELECT has_table_privilege(:r, CAST(:t AS regclass), 'SELECT')"),
                    {"r": role, "t": f"public.{table}"},
                )


async def test_ingest_role_can_only_insert_readings(db):
    async with db.engine.connect() as connection:

        async def has(table, privilege):
            return await connection.scalar(
                text("SELECT has_table_privilege('sensor_ingest', CAST(:t AS regclass), :p)"),
                {"t": f"public.{table}", "p": privilege},
            )

        assert await has("sensor_readings", "INSERT")
        for privilege in ("SELECT", "UPDATE", "DELETE"):
            assert not await has("sensor_readings", privilege)
        for table in (*SENSOR_TABLES[:3], "plants", "user_profiles"):
            for privilege in ("SELECT", "INSERT", "UPDATE", "DELETE"):
                assert not await has(table, privilege)


async def test_ingest_role_cannot_read_devices(db):
    await seed_claimed_device(db)
    async with db.engine.connect() as connection:
        transaction = await connection.begin()
        await connection.execute(text("SET LOCAL ROLE sensor_ingest"))
        with pytest.raises(DBAPIError, match="permission denied"):
            await connection.execute(text("SELECT * FROM devices"))
        await transaction.rollback()


# ---- sensor_readings ----


async def test_reading_is_stored_and_duplicate_message_once(db):
    await seed_claimed_device(db)
    values = reading()

    assert await insert_as_ingest(db, values) == 1
    assert await insert_as_ingest(db, values) == 0
    assert await count(db, "sensor_readings") == 1


async def test_null_readings_are_accepted(db):
    await seed_claimed_device(db)

    assert await insert_as_ingest(db, reading(measured_at=None, lux=None, soil_raw=None)) == 1


async def test_unknown_device_is_rejected_by_foreign_key(db):
    await seed_claimed_device(db)

    with pytest.raises(IntegrityError):
        await insert_as_ingest(db, reading(device_id=OTHER_DEVICE_ID))
    assert await count(db, "sensor_readings") == 0


@pytest.mark.parametrize("override", [{"lux": -1}, {"soil_raw": -1}, {"soil_raw": 4096}])
async def test_out_of_range_values_are_rejected(db, override):
    await seed_claimed_device(db)

    with pytest.raises(IntegrityError):
        await insert_as_ingest(db, reading(**override))


async def test_unclaimed_device_readings_are_not_blocked_by_db(db):
    # 미claim 기기의 telemetry 차단은 기기별 인증(다음 단계)의 몫이다. DB는 막지 않는다.
    await run(db, "INSERT INTO devices (id) VALUES (:id)", id=DEVICE_ID)

    assert await insert_as_ingest(db) == 1


# ---- devices ----


async def test_device_id_format(db):
    await rejected(db, "INSERT INTO devices (id) VALUES ('not-a-device')")
    await rejected(db, "INSERT INTO devices (id) VALUES ('d40592e7d168')")  # 소문자 불가
    await run(db, "INSERT INTO devices (id) VALUES (:id)", id=DEVICE_ID)


async def test_new_device_is_unclaimed_without_owner_or_token(db):
    await run(db, "INSERT INTO devices (id) VALUES (:id)", id=DEVICE_ID)

    row = (await run(db, "SELECT status, owner_user_id, device_token_hash FROM devices")).one()
    assert tuple(row) == ("UNCLAIMED", None, None)


@pytest.mark.parametrize(
    "columns",
    [
        # CLAIMED인데 소유자/토큰/claim 시각이 빠진 경우
        "status = 'CLAIMED', device_token_hash = :hash, claimed_at = now()",
        "status = 'CLAIMED', owner_user_id = :owner, claimed_at = now()",
        "status = 'CLAIMED', owner_user_id = :owner, device_token_hash = :hash",
        # UNCLAIMED인데 소유자나 토큰이 남은 경우
        "owner_user_id = :owner",
        "device_token_hash = :hash",
        # 정의되지 않은 상태
        "status = 'PENDING'",
    ],
)
async def test_claimed_state_is_all_or_nothing(db, columns):
    user_id = await seed_user(db)
    await run(db, "INSERT INTO devices (id) VALUES (:id)", id=DEVICE_ID)

    await rejected(
        db,
        f"UPDATE devices SET {columns} WHERE id = :id",
        id=DEVICE_ID,
        owner=user_id,
        hash=token_hash(1),
    )


async def test_claim_completes_atomically_and_can_be_reset(db):
    user_id = await seed_user(db)
    await run(db, "INSERT INTO devices (id) VALUES (:id)", id=DEVICE_ID)

    await run(
        db,
        "UPDATE devices SET status = 'CLAIMED', owner_user_id = :owner, "
        "device_token_hash = :hash, claimed_at = now() WHERE id = :id",
        id=DEVICE_ID,
        owner=user_id,
        hash=token_hash(1),
    )
    await run(
        db,
        "UPDATE devices SET status = 'UNCLAIMED', owner_user_id = NULL, "
        "device_token_hash = NULL WHERE id = :id",
        id=DEVICE_ID,
    )


async def test_device_token_hash_is_unique_and_sha256_length(db):
    user_id = await seed_user(db)
    await run(db, INSERT_CLAIMED, id=DEVICE_ID, owner=user_id, hash=token_hash(1))

    await rejected(db, INSERT_CLAIMED, id=OTHER_DEVICE_ID, owner=user_id, hash=token_hash(1))
    await rejected(db, INSERT_CLAIMED, id=OTHER_DEVICE_ID, owner=user_id, hash="short")


# ---- device_claims ----

INSERT_CLAIM = (
    "INSERT INTO device_claims (device_id, user_id, claim_token_hash, status, expires_at, "
    "completed_at) VALUES (:device, :user, :hash, :status, :expires, :completed)"
)


def claim_params(user_id, n, status="PENDING", completed=None):
    return {
        "device": DEVICE_ID,
        "user": user_id,
        "hash": token_hash(n),
        "status": status,
        "expires": datetime.now(UTC) + timedelta(minutes=10),
        "completed": completed,
    }


async def test_only_one_pending_claim_per_device(db):
    user_id = await seed_user(db)
    await run(db, "INSERT INTO devices (id) VALUES (:id)", id=DEVICE_ID)
    await run(db, INSERT_CLAIM, **claim_params(user_id, 1))

    await rejected(db, INSERT_CLAIM, **claim_params(user_id, 2))
    # 끝난 claim은 여러 개여도 된다.
    now = datetime.now(UTC)
    await run(db, INSERT_CLAIM, **claim_params(user_id, 3, "EXPIRED"))
    await run(db, INSERT_CLAIM, **claim_params(user_id, 4, "COMPLETED", now))
    await run(db, INSERT_CLAIM, **claim_params(user_id, 5, "CANCELLED"))


async def test_claim_completed_at_matches_status_and_hash_rules(db):
    user_id = await seed_user(db)
    await run(db, "INSERT INTO devices (id) VALUES (:id)", id=DEVICE_ID)
    now = datetime.now(UTC)

    await rejected(db, INSERT_CLAIM, **claim_params(user_id, 1, "COMPLETED", None))
    await rejected(db, INSERT_CLAIM, **claim_params(user_id, 2, "PENDING", now))
    await rejected(db, INSERT_CLAIM, **claim_params(user_id, 3, "UNKNOWN"))
    await rejected(db, INSERT_CLAIM, **(claim_params(user_id, 4) | {"hash": "short"}))


async def test_claim_token_hash_is_unique(db):
    user_id = await seed_user(db)
    await run(db, "INSERT INTO devices (id) VALUES (:id)", id=DEVICE_ID)
    await run(db, INSERT_CLAIM, **claim_params(user_id, 1, "EXPIRED"))

    await rejected(db, INSERT_CLAIM, **claim_params(user_id, 1, "EXPIRED"))


# ---- plant_devices ----


async def test_one_device_per_plant_and_one_plant_per_device(db):
    user_id = await seed_claimed_device(db)
    await run(db, INSERT_CLAIMED, id=OTHER_DEVICE_ID, owner=user_id, hash=token_hash(2))
    plant_id = await seed_plant(db, user_id)
    other_plant_id = await seed_plant(db, user_id)
    link = "INSERT INTO plant_devices (device_id, plant_id) VALUES (:device, :plant)"

    await run(db, link, device=DEVICE_ID, plant=plant_id)
    await rejected(db, link, device=OTHER_DEVICE_ID, plant=plant_id)  # 식물에 기기 둘
    await rejected(db, link, device=DEVICE_ID, plant=other_plant_id)  # 기기에 식물 둘


# ---- 삭제 연쇄 ----


async def test_deleting_plant_only_removes_the_link(db):
    user_id = await seed_claimed_device(db)
    plant_id = await seed_plant(db, user_id)
    await run(db, "INSERT INTO plant_devices VALUES (:d, :p)", d=DEVICE_ID, p=plant_id)
    await insert_as_ingest(db)

    await run(db, "DELETE FROM plants WHERE id = :id", id=plant_id)

    assert await count(db, "plant_devices") == 0
    assert await count(db, "devices") == 1
    assert await count(db, "sensor_readings") == 1


async def test_deleting_device_removes_claims_link_and_readings(db):
    user_id = await seed_claimed_device(db)
    plant_id = await seed_plant(db, user_id)
    await run(db, "INSERT INTO plant_devices VALUES (:d, :p)", d=DEVICE_ID, p=plant_id)
    await run(db, INSERT_CLAIM, **claim_params(user_id, 1, "EXPIRED"))
    await insert_as_ingest(db)

    await run(db, "DELETE FROM devices WHERE id = :id", id=DEVICE_ID)

    for table in ("device_claims", "plant_devices", "sensor_readings"):
        assert await count(db, table) == 0


async def test_deleting_owner_removes_devices(db):
    user_id = await seed_claimed_device(db)
    await insert_as_ingest(db)

    await run(db, "DELETE FROM auth.users WHERE id = :id", id=user_id)

    assert await count(db, "devices") == 0
    assert await count(db, "sensor_readings") == 0
