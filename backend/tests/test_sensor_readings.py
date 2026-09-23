"""Real PostgreSQL checks; opt in only with a disposable local leafie_sensor_test DB."""

import os
import runpy
from datetime import UTC, date, datetime
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
from app.models.sensor import SensorDevice, SensorReading
from app.models.user import UserProfile

MIGRATION = Path(__file__).parents[1] / "alembic/versions/cd31c92afd23_add_sensor_readings.py"
DEVICE_ID = "D40592E7D168"
INSERT_READING = text(
    "INSERT INTO sensor_readings "
    "(device_id, sqs_message_id, measured_at, received_at, lux, soil_raw) "
    "VALUES (:device_id, :message_id, :measured_at, :received_at, :lux, :soil_raw) "
    # 충돌 대상을 지정하면 그 컬럼의 SELECT 권한이 필요하다. sensor_ingest는 INSERT만 갖는다.
    "ON CONFLICT DO NOTHING"
)


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


def test_sensor_models_match_migration_contract() -> None:
    devices = Base.metadata.tables["sensor_devices"]
    readings = Base.metadata.tables["sensor_readings"]

    assert {c.name for c in devices.columns} == {
        "device_id",
        "user_id",
        "plant_id",
        "created_at",
        "updated_at",
    }
    assert {c.name for c in readings.columns} == {
        "id",
        "device_id",
        "sqs_message_id",
        "measured_at",
        "received_at",
        "lux",
        "soil_raw",
    }
    # 센서 읽기 실패/시각 동기화 전 값은 null로 들어온다.
    for column in ("measured_at", "lux", "soil_raw"):
        assert readings.columns[column].nullable is True
    assert readings.columns["received_at"].nullable is False
    assert readings.columns["sqs_message_id"].unique is True
    assert next(iter(readings.foreign_keys)).ondelete == "CASCADE"
    plant_index = next(i for i in devices.indexes if i.name == "uq_sensor_devices_plant_id")
    assert plant_index.unique is True


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
            await connection.execute(delete(SpeciesCareGuide))
        await database.close()


async def seed_device(db, *, plant=False):
    user_id, plant_id = uuid4(), uuid4()
    async with db.session_context() as session:
        await session.execute(AUTH_USERS_TABLE.insert().values(id=user_id))
        session.add(UserProfile(user_id=user_id, nickname="집사"))
        guide_id = str(uuid4())
        session.add(
            SpeciesCareGuide(species_reference_id=guide_id, display_name="바질", category="HERB")
        )
        await session.flush()
        if plant:
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
            await session.flush()
        session.add(
            SensorDevice(device_id=DEVICE_ID, user_id=user_id, plant_id=plant_id if plant else None)
        )
    return user_id, plant_id


async def insert_as_ingest(db, statement=INSERT_READING, values=None):
    """Lambda가 쓰는 sensor_ingest 역할로 실행한다."""
    async with db.engine.connect() as connection:
        transaction = await connection.begin()
        await connection.execute(text("SET LOCAL ROLE sensor_ingest"))
        result = await connection.execute(statement, values or reading())
        await transaction.commit()
        return result.rowcount


async def count_readings(db) -> int:
    async with db.engine.connect() as connection:
        return await connection.scalar(text("SELECT count(*) FROM sensor_readings"))


async def test_tables_have_rls_and_are_hidden_from_app_roles(db):
    async with db.engine.connect() as connection:
        for table in ("sensor_devices", "sensor_readings"):
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
    await seed_device(db)
    async with db.engine.connect() as connection:
        assert await connection.scalar(
            text("SELECT has_table_privilege('sensor_ingest', 'public.sensor_readings', 'INSERT')")
        )
        for privilege in ("SELECT", "UPDATE", "DELETE"):
            assert not await connection.scalar(
                text(
                    "SELECT has_table_privilege('sensor_ingest', 'public.sensor_readings', "
                    f"'{privilege}')"
                )
            )
        for table in ("sensor_devices", "plants", "user_profiles"):
            assert not await connection.scalar(
                text(f"SELECT has_table_privilege('sensor_ingest', 'public.{table}', 'SELECT')")
            )

    assert await insert_as_ingest(db) == 1
    assert await count_readings(db) == 1


async def test_duplicate_sqs_message_is_stored_once(db):
    await seed_device(db)
    values = reading()

    assert await insert_as_ingest(db, values=values) == 1
    assert await insert_as_ingest(db, values=values) == 0
    assert await count_readings(db) == 1


async def test_null_readings_are_accepted(db):
    await seed_device(db)

    assert (
        await insert_as_ingest(db, values=reading(measured_at=None, lux=None, soil_raw=None)) == 1
    )


async def test_unknown_device_is_rejected_by_foreign_key(db):
    await seed_device(db)

    with pytest.raises(IntegrityError):
        await insert_as_ingest(db, values=reading(device_id="AAAAAAAAAAAA"))
    assert await count_readings(db) == 0


@pytest.mark.parametrize(
    "override",
    [{"lux": -1}, {"soil_raw": -1}, {"soil_raw": 4096}],
)
async def test_out_of_range_values_are_rejected(db, override):
    await seed_device(db)

    with pytest.raises(IntegrityError):
        await insert_as_ingest(db, values=reading(**override))


async def test_ingest_role_cannot_touch_other_tables(db):
    await seed_device(db)
    async with db.engine.connect() as connection:
        transaction = await connection.begin()
        await connection.execute(text("SET LOCAL ROLE sensor_ingest"))
        with pytest.raises(DBAPIError, match="permission denied"):
            await connection.execute(text("SELECT * FROM sensor_devices"))
        await transaction.rollback()


async def test_device_id_format_and_single_device_per_plant(db):
    user_id, plant_id = await seed_device(db, plant=True)
    insert_device = text(
        "INSERT INTO sensor_devices (device_id, user_id, plant_id) VALUES (:d, :u, :p)"
    )

    with pytest.raises(IntegrityError):
        async with db.engine.begin() as connection:
            await connection.execute(insert_device, {"d": "not-a-device", "u": user_id, "p": None})

    # 한 식물에는 기기 하나만 연결할 수 있다.
    with pytest.raises(IntegrityError):
        async with db.engine.begin() as connection:
            await connection.execute(
                insert_device, {"d": "AAAAAAAAAAAA", "u": user_id, "p": plant_id}
            )

    # 식물에 연결하지 않은 기기는 여러 대여도 된다.
    async with db.engine.begin() as connection:
        for device_id in ("BBBBBBBBBBBB", "CCCCCCCCCCCC"):
            await connection.execute(insert_device, {"d": device_id, "u": user_id, "p": None})


async def test_deleting_device_cascades_readings_and_plant_delete_unlinks(db):
    _, plant_id = await seed_device(db, plant=True)
    await insert_as_ingest(db)

    async with db.engine.begin() as connection:
        await connection.execute(text("DELETE FROM plants WHERE id = :id"), {"id": plant_id})
        assert (
            await connection.scalar(
                text("SELECT plant_id FROM sensor_devices WHERE device_id = :d"),
                {"d": DEVICE_ID},
            )
            is None
        )
        await connection.execute(
            text("DELETE FROM sensor_devices WHERE device_id = :d"), {"d": DEVICE_ID}
        )
        assert await connection.scalar(text("SELECT count(*) FROM sensor_readings")) == 0


def test_model_classes_are_registered() -> None:
    import app.models as models

    assert models.SensorDevice is SensorDevice
    assert models.SensorReading is SensorReading
