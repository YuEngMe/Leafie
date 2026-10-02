import asyncio
import json
import runpy
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest
from sqlalchemy import delete, func, select, text

from app.models.care import CareEvent
from app.models.notification import Notification
from app.models.plant import Plant, SpeciesCareGuide
from app.models.sensor import PlantSensorDevice, PlantSensorEvent, SensorDevice, SensorReading
from app.schemas.plant import HomeDialogueKey
from app.schemas.sensor import SensorAssessment, SensorLevel, SensorMetricAssessment
from app.services.plant_management import HomeDialogueEvent
from app.services.sensor_assessment import (
    SensorAssessmentService,
    SQLAlchemyLetterSensorSummary,
    ThresholdRange,
    classify,
    day_window,
    parse_thresholds,
)
from app.tasks.sensor_notification import SensorNotificationCollectHandler
from tests.test_care_postgres import care_db  # noqa: F401
from tests.test_plant_management import build_service, make_plant

MIGRATION = runpy.run_path(
    str(Path(__file__).parents[1] / "alembic/versions/b6e2d8a41f90_add_species_sensor_policy.py")
)
NOW = datetime(2026, 10, 2, 3, 0, tzinfo=UTC)
DEVICE = "CA11B1230001"


@pytest.mark.parametrize(
    "value,state",
    [
        (None, "UNKNOWN"),
        (float("nan"), "UNKNOWN"),
        (float("inf"), "UNKNOWN"),
        (39, "LOW"),
        (40, "OK"),
        (90, "OK"),
        (91, "HIGH"),
    ],
)
def test_classification_boundaries(value, state):
    assert classify(value, ThresholdRange(lower=40, upper=90)) == state


def test_all_catalog_policies_are_versioned_and_explicitly_provisional():
    catalog = runpy.run_path(
        str(
            Path(__file__).parents[1]
            / "alembic/versions/9c49cb212775_seed_initial_species_catalog.py"
        )
    )["CATALOG"]
    assert {f"catalog:{key}" for key in MIGRATION["SPECIES"]} == {
        row["species_reference_id"] for row in catalog
    }
    for species in MIGRATION["SPECIES"]:
        policy = MIGRATION["policy"](species)
        assert policy["status"] == "PROVISIONAL"
        assert policy["references_supply_numeric_thresholds"] is False
        if species == "tulipa-gesneriana":
            assert parse_thresholds({"sensor_thresholds": policy}) is None
        else:
            assert parse_thresholds({"sensor_thresholds": policy}).version == MIGRATION["VERSION"]
    assert classify(1000000, ThresholdRange(lower=60000)) == "OK"


@pytest.mark.parametrize(
    "patch",
    [
        {"soil_unit": "humidity"},
        {"light_unit": "DLI"},
        {"status": "DRAFT"},
        {"soil_percent": {"lower": 90, "upper": 40}},
        {"soil_percent": {"lower": 40, "upper": 101}},
        {"enabled": False},
    ],
)
def test_bad_or_disabled_policy_is_not_used(patch):
    policy = MIGRATION["policy"]("ocimum-basilicum") | patch
    assert parse_thresholds({"sensor_thresholds": policy}) is None


def test_local_days_preserve_dst_duration():
    from datetime import date

    start, end = day_window(date(2026, 11, 1), "America/New_York")
    assert end - start == timedelta(hours=25)


@pytest.fixture
async def assessment_db(care_db):  # noqa: F811
    db, user_id, plant_id = care_db
    async with db.session_context() as session:
        plant = await session.get(Plant, plant_id)
        guide = await session.get(SpeciesCareGuide, plant.species_reference_id)
        guide.care_profile = {"sensor_thresholds": MIGRATION["policy"]("ocimum-basilicum")}
        session.add(
            SensorDevice(
                id=DEVICE,
                owner_user_id=user_id,
                sensor_token_hash="d" * 64,
                status="CLAIMED",
                claimed_at=NOW - timedelta(days=3),
            )
        )
        await session.flush()
        session.add(
            PlantSensorDevice(
                plant_id=plant_id,
                device_id=DEVICE,
                created_at=NOW - timedelta(days=3),
            )
        )
    try:
        yield db, user_id, plant_id
    finally:
        async with db.session_context() as session:
            await session.execute(delete(SensorDevice).where(SensorDevice.id == DEVICE))


async def add_readings(db, timestamps, *, raw=3000, lux=100, repeats=1):
    async with db.session_context() as session:
        for timestamp in timestamps:
            for _ in range(repeats):
                session.add(
                    SensorReading(
                        device_id=DEVICE,
                        sqs_message_id=uuid4(),
                        measured_at=timestamp,
                        received_at=timestamp,
                        lux=lux,
                        soil_raw=raw,
                    )
                )


async def read(db, plant_id, **kwargs):
    async with db.session_context() as session:
        return await SensorAssessmentService(session).read(plant_id, now=NOW, **kwargs)


async def test_actual_db_low_soil_deduplication_and_completed_day_light(assessment_db):
    db, _, plant_id = assessment_db
    await add_readings(db, [NOW - timedelta(minutes=i) for i in (5, 15, 25)], repeats=2)
    start, end = day_window(NOW.date() - timedelta(days=1), "Asia/Seoul")
    await add_readings(db, [start + timedelta(minutes=i * 10) for i in range(144)], repeats=2)
    result = await read(db, plant_id)
    assert result.provisional
    assert result.soil.state == "LOW"
    assert result.soil.sample_count == 3
    assert result.light.date == NOW.date() - timedelta(days=1)
    assert result.light.sample_count == 144
    assert result.light.coverage_ratio == 1
    assert result.light.value == 2400
    assert result.light.state == "LOW"
    assert result.connection == "ACTIVE"


async def test_partial_day_missing_data_and_future_readings_are_unknown(assessment_db):
    db, _, plant_id = assessment_db
    await add_readings(db, [NOW - timedelta(minutes=5)], repeats=4)
    await add_readings(db, [NOW + timedelta(minutes=5)], raw=1000)
    current = await read(db, plant_id, day=NOW.date())
    assert current.soil.state == "UNKNOWN"
    assert current.soil.sample_count == 1
    assert current.light.state == "UNKNOWN"
    assert current.light.reason == "DAY_IN_PROGRESS"
    previous = await read(db, plant_id)
    assert previous.light.value is None
    assert previous.light.reason == "INSUFFICIENT_COVERAGE"


async def test_median_rejects_single_spike_and_stale_data(assessment_db):
    db, _, plant_id = assessment_db
    await add_readings(db, [NOW - timedelta(minutes=5)], raw=4095)
    await add_readings(db, [NOW - timedelta(minutes=i) for i in (15, 25)], raw=2300)
    result = await read(db, plant_id)
    assert result.soil.state == "OK"
    assert result.soil.value == 50
    async with db.session_context() as session:
        stale = await SensorAssessmentService(session).read(plant_id, now=NOW + timedelta(hours=1))
    assert stale.connection == "STALE"
    assert stale.soil.state == stale.light.state == "UNKNOWN"


async def test_link_cutoff_rejects_previous_owners_readings(assessment_db):
    db, _, plant_id = assessment_db
    await add_readings(db, [NOW - timedelta(minutes=i) for i in (5, 15, 25)])
    async with db.session_context() as session:
        link = await session.get(PlantSensorDevice, DEVICE)
        link.created_at = NOW - timedelta(minutes=1)
    result = await read(db, plant_id)
    assert result.soil.state == result.light.state == "UNKNOWN"


async def test_sensor_event_and_notification_are_atomic_daily_and_survive_alert_delete(
    assessment_db,
):
    db, _, plant_id = assessment_db
    await add_readings(db, [NOW - timedelta(minutes=i) for i in (5, 15, 25)])
    collector = SensorNotificationCollectHandler(db)
    assert await collector.collect(NOW) == 1
    assert await collector.collect(NOW) == 0
    async with db.session_context() as session:
        event = await session.scalar(
            select(PlantSensorEvent).where(PlantSensorEvent.plant_id == plant_id)
        )
        notification = await session.scalar(
            select(Notification).where(Notification.plant_id == plant_id)
        )
        assert event.type == "SOIL_LOW"
        assert notification.type == "SENSOR_SOIL_LOW"
        assert notification.source_id == event.id
        await session.delete(notification)
        session.add(
            CareEvent(
                plant_id=plant_id,
                type="WATERING",
                source="USER_CREATED",
                status="COMPLETED",
                due_date=NOW.date(),
                performed_on=NOW.date(),
                recorded_at=NOW + timedelta(minutes=1),
            )
        )
    assert await collector.collect(NOW) == 0
    summary = json.loads(await SQLAlchemyLetterSensorSummary(db).read(plant_id, NOW.date()))
    assert summary["waterRequests"][0]["wateringRecordedAfterRequest"]
    assert summary["wateringRecordedCount"] == 1
    async with db.session_context() as session:
        assert await session.scalar(select(func.count()).select_from(PlantSensorEvent)) == 1


async def test_collector_does_not_revive_deleted_plants(assessment_db):
    db, _, plant_id = assessment_db
    await add_readings(db, [NOW - timedelta(minutes=i) for i in (5, 15, 25)])
    async with db.session_context() as session:
        plant = await session.get(Plant, plant_id)
        plant.deleted_at = NOW
    assert await SensorNotificationCollectHandler(db).collect(NOW) == 0


async def test_concurrent_collectors_create_one_event(assessment_db):
    db, _, plant_id = assessment_db
    await add_readings(db, [NOW - timedelta(minutes=i) for i in (5, 15, 25)])
    counts = await asyncio.gather(
        SensorNotificationCollectHandler(db).collect(NOW),
        SensorNotificationCollectHandler(db).collect(NOW),
    )
    assert sum(counts) == 1
    async with db.session_context() as session:
        assert (
            await session.scalar(
                select(func.count())
                .select_from(PlantSensorEvent)
                .where(PlantSensorEvent.plant_id == plant_id)
            )
            == 1
        )


async def test_notification_failure_rolls_back_sensor_event(assessment_db):
    from unittest.mock import patch

    db, _, plant_id = assessment_db
    await add_readings(db, [NOW - timedelta(minutes=i) for i in (5, 15, 25)])
    with patch("app.tasks.sensor_notification.Notification", side_effect=RuntimeError("failure")):
        with pytest.raises(RuntimeError, match="failure"):
            await SensorNotificationCollectHandler(db).collect(NOW)
    async with db.session_context() as session:
        assert (
            await session.scalar(
                select(func.count())
                .select_from(PlantSensorEvent)
                .where(PlantSensorEvent.plant_id == plant_id)
            )
            == 0
        )
    assert await SensorNotificationCollectHandler(db).collect(NOW) == 1


async def test_missing_or_disabled_thresholds_never_create_alerts(assessment_db):
    db, _, plant_id = assessment_db
    assert (await read(db, plant_id)).connection == "NO_DATA"
    await add_readings(db, [NOW - timedelta(minutes=i) for i in (5, 15, 25)])
    for profile in ({}, {"sensor_thresholds": MIGRATION["policy"]("tulipa-gesneriana")}):
        async with db.session_context() as session:
            plant = await session.get(Plant, plant_id)
            guide = await session.get(SpeciesCareGuide, plant.species_reference_id)
            guide.care_profile = profile
        result = await read(db, plant_id)
        assert result.soil.state == result.light.state == "UNKNOWN"
        assert result.soil.reason == "THRESHOLDS_UNAVAILABLE"
        assert await SensorNotificationCollectHandler(db).collect(NOW) == 0


async def test_home_consumes_sensor_states_and_filters_resolved_dialogues():
    user_id = uuid4()
    plant = make_plant(user_id, created_at=NOW - timedelta(days=10))
    service, repository, _, _ = build_service([plant])
    sensor = SensorAssessment(
        connection="ACTIVE",
        soil=SensorMetricAssessment(
            unit="relative_percent",
            state="LOW",
            value=20,
        ),
        light=SensorMetricAssessment(unit="lux_hours", state="UNKNOWN"),
    )
    service._assessments = SimpleNamespace(read=AsyncMock(return_value=sensor))
    repository.dialogue_events = [
        HomeDialogueEvent(uuid4(), HomeDialogueKey.SOIL_MOISTURE_LOW, NOW)
    ]
    home = await service.get_home(user_id, plant.id, now=NOW)
    assert home.room.dialogue_key == "SOIL_MOISTURE_LOW"
    assert home.plant.expression_id == "expression_sad"
    assert home.room.sensor.soil.state == "LOW"
    sensor.soil.state = SensorLevel.OK
    sensor.light.state = SensorLevel.OK
    home = await service.get_home(user_id, plant.id, now=NOW)
    assert home.room.dialogue_queue == []
    assert home.plant.expression_id == "expression_happy"


async def test_home_uses_optimal_light_dialogue_when_no_higher_priority_prompt():
    user_id = uuid4()
    plant = make_plant(user_id, created_at=NOW)
    service, _, _, _ = build_service([plant])
    sensor = SensorAssessment(
        connection="ACTIVE",
        soil=SensorMetricAssessment(unit="relative_percent", state="OK", value=50),
        light=SensorMetricAssessment(unit="lux_hours", state="OK", value=65000),
    )
    service._assessments = SimpleNamespace(read=AsyncMock(return_value=sensor))
    home = await service.get_home(user_id, plant.id, now=NOW)
    assert home.room.dialogue_key == "LIGHT_OPTIMAL"


async def test_new_migration_preserves_profiles_custom_thresholds_and_rls(care_db):  # noqa: F811
    db, _, plant_id = care_db
    async with db.session_context() as session:
        plant = await session.get(Plant, plant_id)
        guide = await session.get(SpeciesCareGuide, plant.species_reference_id)
        guide.care_profile = {"light": "FULL_SUN"}
        # The seeded catalog key is needed to exercise the data migration.
        session.add(
            SpeciesCareGuide(
                species_reference_id="catalog:ocimum-basilicum",
                display_name="바질",
                category="HERB",
                care_profile={"light": "FULL_SUN"},
            )
        )
        session.add(
            SpeciesCareGuide(
                species_reference_id="catalog:epipremnum-aureum",
                display_name="스킨답서스",
                category="FOLIAGE",
                care_profile={"sensor_thresholds": {"version": "custom", "enabled": False}},
            )
        )
    try:
        async with db.engine.begin() as connection:
            await connection.execute(text("DROP TABLE plant_sensor_events"))
            for role in ("anon", "authenticated"):
                await connection.execute(
                    text(
                        f"DO $$ BEGIN CREATE ROLE {role}; "
                        "EXCEPTION WHEN duplicate_object THEN NULL; END $$"
                    )
                )

            def upgrade(sync_connection):
                from alembic.migration import MigrationContext
                from alembic.operations import Operations

                with Operations.context(MigrationContext.configure(sync_connection)):
                    original = MIGRATION["op"].execute

                    def execute(statement):
                        if "pg_cron" in str(statement) or "cron.schedule" in str(statement):
                            assert text(str(statement)).compile().params == {}
                            return
                        return original(statement)

                    from unittest.mock import patch

                    with patch.object(MIGRATION["op"], "execute", execute):
                        MIGRATION["upgrade"]()

            await connection.run_sync(upgrade)
            assert await connection.scalar(
                text("SELECT relrowsecurity FROM pg_class WHERE relname='plant_sensor_events'")
            )
            assert not await connection.scalar(
                text("SELECT has_table_privilege('authenticated', 'plant_sensor_events', 'SELECT')")
            )
        async with db.session_context() as session:
            guide = await session.get(SpeciesCareGuide, "catalog:ocimum-basilicum")
            assert guide.care_profile["light"] == "FULL_SUN"
            assert guide.care_profile["sensor_thresholds"]["version"] == MIGRATION["VERSION"]
            custom = await session.get(SpeciesCareGuide, "catalog:epipremnum-aureum")
            assert custom.care_profile["sensor_thresholds"] == {
                "version": "custom",
                "enabled": False,
            }
    finally:
        async with db.session_context() as session:
            await session.execute(
                delete(SpeciesCareGuide).where(
                    SpeciesCareGuide.species_reference_id.in_(
                        ["catalog:ocimum-basilicum", "catalog:epipremnum-aureum"]
                    )
                )
            )
