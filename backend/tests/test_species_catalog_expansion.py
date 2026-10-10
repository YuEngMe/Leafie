import runpy
from contextlib import asynccontextmanager
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError

from app.integrations.plantnet import PlantNetCandidate
from app.models.plant import Plant, SpeciesCareGuide
from app.services.sensor_assessment import SensorThresholds, classify, parse_thresholds
from app.services.species import SQLAlchemySpeciesRepository, guide_to_candidate
from app.tasks.species import SpeciesIdentificationRepository, find_matching_guide
from tests.test_care_postgres import care_db  # noqa: F401

VERSIONS = Path(__file__).parents[1] / "alembic/versions"
MIGRATION = runpy.run_path(str(VERSIONS / "c8f1a7e2d409_expand_supported_species_catalog.py"))
ROWS = MIGRATION["rows"]()


def test_expansion_has_five_unique_new_guides_and_no_excluded_trade_name():
    initial = runpy.run_path(str(VERSIONS / "9c49cb212775_seed_initial_species_catalog.py"))[
        "CATALOG"
    ]
    assert {row["display_name"] for row in ROWS} == {
        "스파티필름",
        "스투키",
        "토마토",
        "극락조",
        "괴마옥",
    }
    combined = [*initial, *ROWS]
    for key in ("species_reference_id", "gbif_id", "plantnet_species_id"):
        values = [row[key] for row in combined if row[key] is not None]
        assert len(values) == len(set(values))
    assert len(combined) == 28


@pytest.mark.parametrize("row", ROWS, ids=lambda row: row["species_reference_id"])
def test_new_guides_supply_complete_care_diagnosis_and_api_defaults(row):
    guide = SpeciesCareGuide(**row)
    candidate = guide_to_candidate(guide)
    assert candidate.reference_id == row["species_reference_id"]
    assert candidate.default_care.watering_interval_days > 0
    assert candidate.default_care.repotting_interval_days == row["default_repotting_interval_days"]
    assert candidate.recommended_water is None
    assert guide.data_version == MIGRATION["DATA_VERSION"]
    assert guide.reviewed_at == MIGRATION["REVIEWED_AT"]
    care = guide.care_profile
    for field in ("growth_context", "light", "soil_moisture", "soil", "humidity", "care_notes"):
        assert care[field]
    assert care["watering"]["schedule_value_is_derived"] is True
    assert care["watering"]["warm_season_interval_days"] == guide.default_watering_interval_days
    assert care["repotting"]["baseline_interval_days"] == guide.default_repotting_interval_days
    assert care["toxicity"]["warning"]
    assert guide.diagnosis_profile["symptom_checks"]
    assert "가능한 원인" in guide.diagnosis_profile["disclaimer"]
    assert "확정 진단" in guide.diagnosis_profile["disclaimer"]
    assert all(source["url"].startswith("https://") for source in guide.source_references)
    assert all(source["accessed_on"] == "2026-10-10" for source in guide.source_references)


@pytest.mark.parametrize("row", ROWS, ids=lambda row: row["species_reference_id"])
def test_new_sensor_policies_reuse_provisional_units_and_boundary_contract(row):
    policy = row["care_profile"]["sensor_thresholds"]
    parsed = SensorThresholds.model_validate(policy)
    assert parsed.status == "PROVISIONAL"
    assert parsed.version == MIGRATION["SENSOR_VERSION"]
    assert policy["basis"] == "APP_INITIAL_HEURISTIC_NOT_AGRONOMIC_STANDARD"
    assert policy["references_supply_numeric_thresholds"] is False
    assert classify(parsed.soil_percent.lower, parsed.soil_percent) == "OK"
    assert classify(parsed.soil_percent.upper, parsed.soil_percent) == "OK"
    assert classify(parsed.soil_percent.lower - 1, parsed.soil_percent) == "LOW"
    if row["display_name"] == "괴마옥":
        assert parse_thresholds(row["care_profile"]) is None
        assert row["gbif_id"] is None
        assert row["plantnet_species_id"] is None
        assert row["care_profile"]["taxonomy"]["photo_matching_enabled"] is False
    else:
        assert parse_thresholds(row["care_profile"]) is not None


def test_representatives_do_not_alias_distinct_species_and_tomato_has_no_repot_cycle():
    by_name = {row["display_name"]: row for row in ROWS}
    assert "Dracaena angolensis" not in by_name["스투키"]["aliases"]
    assert "Sansevieria cylindrica" not in by_name["스투키"]["aliases"]
    assert "Strelitzia nicolai" not in by_name["극락조"]["aliases"]
    assert "Euphorbia hypogaea" not in by_name["괴마옥"]["aliases"]
    assert by_name["토마토"]["default_repotting_interval_days"] is None


def migrate(connection, direction):
    from alembic.migration import MigrationContext
    from alembic.operations import Operations

    with Operations.context(MigrationContext.configure(connection)):
        MIGRATION[direction]()


async def test_photo_repository_excludes_unresolved_trade_hybrid():
    guides = [SpeciesCareGuide(**row) for row in ROWS]
    session = SimpleNamespace(scalars=AsyncMock(return_value=SimpleNamespace(all=lambda: guides)))

    @asynccontextmanager
    async def session_context():
        yield session

    repository = SpeciesIdentificationRepository(SimpleNamespace(session_context=session_context))
    matches = await repository.find_guides(
        [PlantNetCandidate("Euphorbia hypogaea", ("괴마옥",), 0.9)]
    )
    assert "alias:괴마옥" not in matches
    assert "name:euphorbia hybrid" not in matches
    assert "gbif:2869680" in matches
    for row in ROWS[:4]:
        candidate = PlantNetCandidate(row["scientific_name"], (), 0.9, row["gbif_id"])
        assert (
            find_matching_guide(candidate, matches).species_reference_id
            == row["species_reference_id"]
        )


async def test_migration_search_photo_matching_and_rollback_preserve_existing_data(care_db):  # noqa: F811
    db, user_id, plant_id = care_db
    ids = [row["species_reference_id"] for row in ROWS]
    async with db.session_context() as session:
        plant = await session.get(Plant, plant_id)
        original_reference = plant.species_reference_id
        original = await session.get(SpeciesCareGuide, original_reference)
        original_profile = dict(original.care_profile)
    try:
        async with db.engine.begin() as connection:
            await connection.run_sync(lambda conn: migrate(conn, "upgrade"))
            with pytest.raises(IntegrityError):
                async with connection.begin_nested():
                    await connection.run_sync(lambda conn: migrate(conn, "upgrade"))
        async with db.session_context() as session:
            repository = SQLAlchemySpeciesRepository(session)
            for row in ROWS:
                for query in (row["display_name"], row["scientific_name"], *row["aliases"]):
                    results = await repository.search_guides(query, offset=0, limit=100)
                    assert row["species_reference_id"] in {
                        item.species_reference_id for item in results
                    }
            saved = list(
                await session.scalars(
                    select(SpeciesCareGuide).where(SpeciesCareGuide.species_reference_id.in_(ids))
                )
            )
            assert len(saved) == 5
            for row in ROWS:
                guide = next(
                    item
                    for item in saved
                    if item.species_reference_id == row["species_reference_id"]
                )
                for key, value in row.items():
                    assert getattr(guide, key) == value
            original = await session.get(SpeciesCareGuide, original_reference)
            assert original.care_profile == original_profile
        candidates = [
            PlantNetCandidate(row["scientific_name"], (row["display_name"],), 0.9, row["gbif_id"])
            for row in ROWS
        ]
        matches = await SpeciesIdentificationRepository(db).find_guides(candidates)
        for row, candidate in zip(ROWS, candidates, strict=True):
            guide = find_matching_guide(candidate, matches)
            if row["display_name"] == "괴마옥":
                assert guide is None
                wild_species = PlantNetCandidate("Euphorbia hypogaea", ("괴마옥",), 0.9)
                assert find_matching_guide(wild_species, matches) is None
            else:
                assert guide.species_reference_id == row["species_reference_id"]
        async with db.engine.begin() as connection:
            await connection.execute(
                update(Plant).where(Plant.id == plant_id).values(species_reference_id=ids[0])
            )
            with pytest.raises(IntegrityError):
                async with connection.begin_nested():
                    await connection.run_sync(lambda conn: migrate(conn, "downgrade"))
            await connection.execute(
                update(Plant)
                .where(Plant.id == plant_id)
                .values(species_reference_id=original_reference)
            )
            await connection.run_sync(lambda conn: migrate(conn, "downgrade"))
        async with db.session_context() as session:
            assert (
                list(
                    await session.scalars(
                        select(SpeciesCareGuide).where(
                            SpeciesCareGuide.species_reference_id.in_(ids)
                        )
                    )
                )
                == []
            )
            assert await session.get(SpeciesCareGuide, original_reference) is not None
    finally:
        async with db.engine.begin() as connection:
            await connection.run_sync(lambda conn: migrate(conn, "downgrade"))
