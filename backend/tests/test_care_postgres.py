"""Opt-in persistence checks against a disposable local leafie_care_test database."""

import asyncio
import os
import runpy
from datetime import date, timedelta
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import delete, select, text
from sqlalchemy.engine import make_url

from app.core.config import Settings
from app.core.errors import AppError
from app.db.base import AUTH_USERS_TABLE, Base
from app.db.session import Database
from app.models.care import CareEvent, CareSchedule
from app.models.plant import Plant, SpeciesCareGuide
from app.models.user import UserProfile
from app.schemas.care import CareEventCreateRequest
from app.services.care import CareService, SQLAlchemyCareRepository
from app.services.plant import today_in_timezone


@pytest.fixture
async def care_db():
    url = os.environ.get("CARE_TEST_DATABASE_URL")
    if not url:
        pytest.skip("Set CARE_TEST_DATABASE_URL to a disposable local PostgreSQL database")
    parsed = make_url(url)
    if parsed.host not in ("127.0.0.1", "localhost") or parsed.database != "leafie_care_test":
        pytest.fail("Care tests require a disposable localhost/leafie_care_test database")
    db = Database(Settings(_env_file=None, database_url=url))
    async with db.engine.begin() as connection:
        await connection.execute(text("CREATE SCHEMA IF NOT EXISTS auth"))
        await connection.run_sync(Base.metadata.create_all)
    user_id, plant_id, guide_id = uuid4(), uuid4(), str(uuid4())
    try:
        async with db.session_context() as session:
            await session.execute(AUTH_USERS_TABLE.insert().values(id=user_id))
            session.add(UserProfile(user_id=user_id, nickname="집사"))
            session.add(
                SpeciesCareGuide(
                    species_reference_id=guide_id,
                    display_name="바질",
                    category="HERB",
                    default_repotting_interval_days=365,
                )
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
        yield db, user_id, plant_id
    finally:
        async with db.engine.begin() as connection:
            await connection.execute(
                delete(AUTH_USERS_TABLE).where(AUTH_USERS_TABLE.c.id == user_id)
            )
            await connection.execute(
                delete(SpeciesCareGuide).where(SpeciesCareGuide.species_reference_id == guide_id)
            )
        await db.close()


def request(days: int) -> CareEventCreateRequest:
    return CareEventCreateRequest(
        client_event_id=uuid4(),
        care_type="REPOTTING",
        due_date=today_in_timezone("Asia/Seoul") + timedelta(days=days),
    )


async def create(db, user_id, plant_id, payload):
    async with db.session_context() as session:
        return await CareService(SQLAlchemyCareRepository(session)).create_event(
            user_id, plant_id, payload
        )


async def test_repotting_history_survives_transactions_and_concurrent_retries(care_db):
    db, user_id, plant_id = care_db
    old, middle, latest = request(1), request(8), request(15)
    for payload in (old, middle, latest):
        result = await create(db, user_id, plant_id, payload)
    replays = await asyncio.gather(
        *(create(db, user_id, plant_id, payload) for payload in (old, middle, latest, old))
    )
    assert all(not replay.created and replay.response == result.response for replay in replays)
    for payload in (old, middle, latest):
        with pytest.raises(AppError, match="client_event_id") as error:
            await create(
                db, user_id, plant_id, payload.model_copy(update={"due_date": request(20).due_date})
            )
        assert error.value.code == "CLIENT_EVENT_ID_REUSED"
    async with db.session_context() as session:
        events = list(
            await session.scalars(select(CareEvent).where(CareEvent.plant_id == plant_id))
        )
        assert len(events) == 1
        assert set(events[0].previous_request_hashes) == {
            str(old.client_event_id),
            str(middle.client_event_id),
        }
        schedule = await session.scalar(
            select(CareSchedule).where(CareSchedule.plant_id == plant_id)
        )
        assert schedule.next_due_date == latest.due_date


async def test_migration_preserves_legacy_event_and_key(care_db):
    db, user_id, plant_id = care_db
    old, latest = request(1), request(8)
    original = await create(db, user_id, plant_id, old)
    migration = runpy.run_path(
        str(
            Path(__file__).parents[1]
            / "alembic/versions/b7e3a91d6f20_preserve_care_request_history.py"
        )
    )

    def migrate(connection):
        from alembic.migration import MigrationContext
        from alembic.operations import Operations

        with Operations.context(MigrationContext.configure(connection)):
            migration["downgrade"]()
            migration["upgrade"]()

    async with db.engine.begin() as connection:
        await connection.run_sync(migrate)
    assert (await create(db, user_id, plant_id, old)).response == original.response
    moved = await create(db, user_id, plant_id, latest)
    assert (await create(db, user_id, plant_id, old)).response == moved.response
