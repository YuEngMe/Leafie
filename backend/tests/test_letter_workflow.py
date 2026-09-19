"""Real PostgreSQL checks; opt in only with a disposable local leafie_letter_test DB."""

import asyncio
import base64
import json
import os
import runpy
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import delete, func, inspect, select, text, update
from sqlalchemy.engine import make_url

from app.core.config import Settings
from app.core.errors import AppError
from app.db.base import AUTH_USERS_TABLE, Base
from app.db.session import Database
from app.integrations.openai_letter import (
    LetterCompletion,
    LetterPermanentError,
    LetterTransientError,
)
from app.models.letter import Letter
from app.models.notification import Notification
from app.models.plant import Plant, PlantDiary, SpeciesCareGuide
from app.models.user import UserProfile
from app.schemas.queue import JobType, QueueJob
from app.services.letter import (
    LetterService,
    decode_letter_cursor,
    lock_active_plant,
    reserve_letter,
)
from app.tasks.base import PermanentTaskError
from app.tasks.letter import (
    LetterGenerationHandler,
    LetterPublishHandler,
    SQLAlchemyLetterRepository,
    UnconfiguredLetterSensorSummary,
)
from app.tasks.push import SQLAlchemyPushRepository


class TransactionalTestQueue:
    """Use the same SQL transaction as pgmq.send, without requiring its extension locally."""

    fail = False

    async def enqueue(self, job, *, delay_seconds=0, session=None):
        assert session is not None
        if self.fail:
            raise RuntimeError("test queue unavailable")
        return await session.scalar(
            text(
                "INSERT INTO letter_test_queue (job_type, resource_id, delay_seconds) "
                "VALUES (:kind, :id, :delay) RETURNING id"
            ),
            {"kind": job.job_type.value, "id": job.resource_id, "delay": delay_seconds},
        )


@pytest.fixture
async def db():
    url = os.environ.get("LETTER_TEST_DATABASE_URL")
    if not url:
        pytest.skip("Set LETTER_TEST_DATABASE_URL to a disposable local PostgreSQL database")
    parsed = make_url(url)
    if parsed.host not in ("127.0.0.1", "localhost") or parsed.database != "leafie_letter_test":
        pytest.fail("Letter tests require a disposable localhost/leafie_letter_test database")
    database = Database(Settings(_env_file=None, database_url=url))
    async with database.engine.begin() as connection:
        await connection.execute(text("CREATE SCHEMA IF NOT EXISTS auth"))
        await connection.run_sync(Base.metadata.create_all)
        await connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS letter_test_queue "
                "(id bigserial PRIMARY KEY, job_type text, resource_id uuid, delay_seconds integer)"
            )
        )
    try:
        yield database
    finally:
        async with database.engine.begin() as connection:
            await connection.execute(delete(AUTH_USERS_TABLE))
            await connection.execute(delete(SpeciesCareGuide))
            await connection.execute(text("TRUNCATE letter_test_queue"))
        await database.close()


@pytest.fixture
def queue():
    return TransactionalTestQueue()


async def seed(db, queue, *, reserve=True):
    user_id, plant_id, diary_id = uuid4(), uuid4(), uuid4()
    async with db.session_context() as session:
        await session.execute(AUTH_USERS_TABLE.insert().values(id=user_id))
        session.add(UserProfile(user_id=user_id, nickname="집사"))
        guide_id = str(uuid4())
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
                color_id="green",
                hair_id="leaf",
                expression_id="expression_default",
            )
        )
        await session.flush()
        await lock_active_plant(session, user_id, plant_id)
        session.add(
            PlantDiary(
                id=diary_id,
                plant_id=plant_id,
                diary_date=date(2026, 9, 11),
                content="오늘 같이 책을 읽었어.",
                weather="SUNNY",
                title="햇빛 좋은 날",
            )
        )
        await session.flush()
        letter = (
            await reserve_letter(session, queue, user_id=user_id, diary_id=diary_id, created=True)
            if reserve
            else None
        )
    return user_id, plant_id, diary_id, letter.id if letter else None


def job(letter_id):
    return QueueJob(job_type=JobType.LETTER_GENERATION_RUN, resource_id=letter_id, trace_id="test")


class Sensors:
    calls = 0

    async def read(self, plant_id, diary_date):
        self.calls += 1
        return "테스트 요약: 일일 누적 조도 적정. 급수 요청 후 물주기 완료."


class Provider:
    def __init__(self, error=None):
        self.error = error
        self.inputs = []

    async def generate(self, snapshot, *, safety_user_id):
        self.inputs.append(snapshot)
        if self.error:
            raise self.error
        return LetterCompletion("곁에 있어 줘서 고마워.", "resp-test", "test-model", 10, 20)


async def load(db, letter_id):
    async with db.session_context() as session:
        return await session.get(Letter, letter_id)


async def make_due(db, letter_id):
    async with db.session_context() as session:
        await session.execute(
            update(Letter)
            .where(Letter.id == letter_id)
            .values(scheduled_at=datetime.now(UTC) - timedelta(seconds=1))
        )


async def test_reservation_is_unique_fixed_and_does_not_backfill(db, queue):
    user_id, _, diary_id, letter_id = await seed(db, queue)
    original = await load(db, letter_id)
    assert 300 <= (original.scheduled_at - original.created_at).total_seconds() <= 901
    async with db.session_context() as session:
        repeated = await reserve_letter(
            session, queue, user_id=user_id, diary_id=diary_id, created=True
        )
        assert repeated.id == original.id
        assert repeated.scheduled_at == original.scheduled_at
        assert (
            await reserve_letter(session, queue, user_id=user_id, diary_id=diary_id, created=False)
            is None
        )
        assert await session.scalar(text("SELECT count(*) FROM letter_test_queue")) == 1
    other_user, _, old_diary, _ = await seed(db, queue, reserve=False)
    async with db.session_context() as session:
        assert (
            await reserve_letter(
                session, queue, user_id=other_user, diary_id=old_diary, created=False
            )
            is None
        )
        assert await session.scalar(select(func.count()).select_from(Letter)) == 1


async def test_queue_failure_rolls_back_diary_and_letter(db, queue):
    queue.fail = True
    with pytest.raises(RuntimeError):
        await seed(db, queue)
    async with db.session_context() as session:
        assert await session.scalar(select(func.count()).select_from(PlantDiary)) == 0
        assert await session.scalar(select(func.count()).select_from(Letter)) == 0


async def test_full_flow_hidden_until_publication_and_only_one_notification(db, queue):
    user, plant, diary, letter_id = await seed(db, queue)
    repo, provider = SQLAlchemyLetterRepository(db, queue), Provider()
    handler = LetterGenerationHandler(repo, provider, Sensors())
    await asyncio.gather(handler(job(letter_id)), handler(job(letter_id)))
    assert len(provider.inputs) == 1
    completed = await load(db, letter_id)
    assert completed.status == "COMPLETED"
    assert completed.published_at is None
    async with db.session_context() as session:
        service = LetterService(session)
        assert not (await service.list(user)).items
        assert await service.unread_count(user) == 0
        for mark in (False, True):
            with pytest.raises(AppError) as caught:
                await service.detail(user, letter_id, mark_read=mark)
            assert caught.value.status_code == 404
        assert await session.scalar(select(func.count()).select_from(Notification)) == 0
    await repo.publish(letter_id)  # Early delivery must reschedule, not reveal.
    assert (await load(db, letter_id)).published_at is None
    await make_due(db, letter_id)
    await asyncio.gather(repo.publish(letter_id), repo.publish(letter_id))
    async with db.session_context() as session:
        service = LetterService(session)
        assert len((await service.list(user, plant_id=plant)).items) == 1
        assert await service.unread_count(user) == 1
        detail = await service.detail(user, letter_id)
        assert not detail.is_read  # GET has no read side effect.
        assert not {"input_snapshot", "failure_code", "lease_token", "provider_response_id"} & set(
            detail.model_dump()
        )
        first = await service.detail(user, letter_id, mark_read=True)
        second = await service.detail(user, letter_id, mark_read=True)
        assert first.read_at == second.read_at
        assert await service.unread_count(user) == 0
        assert await session.scalar(select(func.count()).select_from(Notification)) == 1
        assert (
            await session.scalar(
                text(
                    "SELECT count(*) FROM letter_test_queue WHERE job_type='PUSH_NOTIFICATION_SEND'"
                )
            )
            == 1
        )
        notification = await session.scalar(select(Notification))
        notification_id = notification.id
    work = await SQLAlchemyPushRepository(db).load(notification_id)
    assert work.source_id == letter_id
    async with db.session_context() as session:
        await LetterService(session).delete(user, letter_id)
        await LetterService(session).delete(user, letter_id)
        assert await session.get(PlantDiary, diary) is not None
        assert not (await LetterService(session).list(user)).items
        assert await session.scalar(select(func.count()).select_from(Notification)) == 0
    assert await SQLAlchemyPushRepository(db).load(notification_id) is None
    await handler(job(letter_id))
    assert len(provider.inputs) == 1
    async with db.session_context() as session:
        same = await reserve_letter(session, queue, user_id=user, diary_id=diary, created=True)
        assert same.id == letter_id  # Deleted letters still occupy the unique diary slot.


async def test_retry_reuses_snapshot_despite_diary_edit(db, queue):
    user, _, diary, letter_id = await seed(db, queue)
    provider, sensors = Provider(LetterTransientError("TIMEOUT")), Sensors()
    repo = SQLAlchemyLetterRepository(db, queue)
    handler = LetterGenerationHandler(repo, provider, sensors)
    with pytest.raises(RuntimeError):
        await handler(job(letter_id))
    original = await load(db, letter_id)
    assert original.status == "PENDING"
    async with db.session_context() as session:
        await session.execute(
            update(PlantDiary).where(PlantDiary.id == diary).values(content="수정됨")
        )
    provider.error = None
    await handler(job(letter_id))
    assert provider.inputs[0] == provider.inputs[1]
    assert provider.inputs[1].diary_content != "수정됨"
    assert sensors.calls == 1
    assert (await load(db, letter_id)).scheduled_at == original.scheduled_at
    await handler(job(letter_id))
    assert len(provider.inputs) == 2


@pytest.mark.parametrize("failure", [LetterPermanentError("EMPTY"), None])
async def test_permanent_or_unconfigured_sensor_failure_does_not_retry(db, queue, failure):
    _, _, _, letter_id = await seed(db, queue)
    provider = Provider(failure)
    handler = LetterGenerationHandler(
        SQLAlchemyLetterRepository(db, queue),
        provider,
        Sensors() if failure else UnconfiguredLetterSensorSummary(),
    )
    with pytest.raises(PermanentTaskError):
        await handler(job(letter_id))
    assert (await load(db, letter_id)).status == "FAILED"
    await handler(job(letter_id))
    assert len(provider.inputs) == (1 if failure else 0)


async def test_stale_worker_cannot_complete_or_fail_new_claim(db, queue):
    _, _, _, letter_id = await seed(db, queue)
    repo = SQLAlchemyLetterRepository(db, queue)
    old = await repo.start(letter_id)
    assert await repo.start(letter_id) is None
    async with db.session_context() as session:
        await session.execute(
            update(Letter)
            .where(Letter.id == letter_id)
            .values(lease_until=datetime.now(UTC) - timedelta(seconds=1))
        )
    new = await repo.start(letter_id)
    assert new.token != old.token
    result = LetterCompletion("편지", "id", "model", 1, 2)
    await repo.complete(letter_id, old.token, result)
    await repo.fail(letter_id, old.token, "STALE", retry=False)
    assert (await load(db, letter_id)).lease_token == new.token
    await repo.complete(letter_id, new.token, result)
    assert (await load(db, letter_id)).status == "COMPLETED"


async def test_retries_are_bounded_and_exhaustion_cannot_rewrite_completed(db, queue):
    _, _, _, letter_id = await seed(db, queue)
    repo = SQLAlchemyLetterRepository(db, queue, max_attempts=2)
    handler = LetterGenerationHandler(repo, Provider(LetterTransientError("TIMEOUT")), Sensors())
    for _ in range(2):
        with pytest.raises(RuntimeError):
            await handler(job(letter_id))
    letter = await load(db, letter_id)
    assert letter.status == "FAILED" and letter.attempt_count == 2
    assert await repo.start(letter_id) is None


@pytest.mark.parametrize("target", ["plant", "account", "diary"])
async def test_deleted_source_blocks_late_completion_and_publication(db, queue, target):
    user, plant, diary, letter_id = await seed(db, queue)
    repo = SQLAlchemyLetterRepository(db, queue)
    work = await repo.start(letter_id)
    async with db.session_context() as session:
        if target == "plant":
            await session.execute(
                update(Plant).where(Plant.id == plant).values(deleted_at=datetime.now(UTC))
            )
        elif target == "account":
            await session.execute(
                update(UserProfile)
                .where(UserProfile.user_id == user)
                .values(deleted_at=datetime.now(UTC), deletion_status="PENDING")
            )
        else:
            await session.execute(delete(PlantDiary).where(PlantDiary.id == diary))
    await repo.complete(letter_id, work.token, LetterCompletion("편지", "id", "model", 1, 2))
    await repo.publish(letter_id)
    async with db.session_context() as session:
        assert await LetterService(session).unread_count(user) == 0
        assert await session.scalar(select(func.count()).select_from(Notification)) == 0
        if target == "diary":
            assert await session.get(Letter, letter_id) is None


async def test_mailbox_ownership_and_cursor_stability(db, queue):
    user, _, _, letter_id = await seed(db, queue)
    other, _, _, _ = await seed(db, queue, reserve=False)
    repo = SQLAlchemyLetterRepository(db, queue)
    await LetterGenerationHandler(repo, Provider(), Sensors())(job(letter_id))
    await make_due(db, letter_id)
    await repo.publish(letter_id)
    async with db.session_context() as session:
        service = LetterService(session)
        assert not (await service.list(other)).items
        assert await service.unread_count(other) == 0
        for operation in (
            service.detail(other, letter_id),
            service.detail(other, letter_id, mark_read=True),
            service.delete(other, letter_id),
        ):
            with pytest.raises(AppError) as caught:
                await operation
            assert caught.value.status_code == 404


async def test_publish_queue_failure_rolls_back_publication_and_notification(db, queue):
    user, _, _, letter_id = await seed(db, queue)
    repo = SQLAlchemyLetterRepository(db, queue)
    await LetterGenerationHandler(repo, Provider(), Sensors())(job(letter_id))
    await make_due(db, letter_id)
    queue.fail = True
    with pytest.raises(RuntimeError):
        await repo.publish(letter_id)
    assert (await load(db, letter_id)).published_at is None
    async with db.session_context() as session:
        assert await LetterService(session).unread_count(user) == 0
        assert await session.scalar(select(func.count()).select_from(Notification)) == 0
    queue.fail = False
    await repo.publish(letter_id)
    assert (await load(db, letter_id)).published_at is not None


@pytest.mark.parametrize("cursor", ["bad!", "e30", "W10", "WyJuYSIsICJuYSJd"])
def test_invalid_cursor(cursor):
    with pytest.raises(AppError) as caught:
        decode_letter_cursor(cursor)
    assert caught.value.status_code == 422


async def test_migration_upgrade_downgrade_has_rls_and_unique_diary(db):
    from alembic.migration import MigrationContext
    from alembic.operations import Operations

    migration = runpy.run_path(
        str(Path(__file__).parents[1] / "alembic/versions/b2f416a83d09_add_letters.py")
    )

    def run(connection):
        with Operations.context(MigrationContext.configure(connection)):
            migration["downgrade"]()
            migration["upgrade"]()

    async with db.engine.begin() as connection:
        await connection.execute(
            text("DO $$ BEGIN CREATE ROLE anon; EXCEPTION WHEN duplicate_object THEN NULL; END $$")
        )
        await connection.execute(
            text(
                "DO $$ BEGIN CREATE ROLE authenticated; "
                "EXCEPTION WHEN duplicate_object THEN NULL; END $$"
            )
        )
        await connection.run_sync(run)
        assert await connection.scalar(
            text("SELECT relrowsecurity FROM pg_class WHERE oid='public.letters'::regclass")
        )
        assert not await connection.scalar(
            text("SELECT has_table_privilege('authenticated', 'public.letters', 'SELECT')")
        )


async def test_chat_removal_migration_drops_tables_and_chat_media(db):
    from alembic.migration import MigrationContext
    from alembic.operations import Operations

    migration = runpy.run_path(
        str(Path(__file__).parents[1] / "alembic/versions/f3a7c9d42e10_drop_legacy_chat.py")
    )
    user_id = uuid4()
    media_id = uuid4()

    async with db.engine.begin() as connection:
        await connection.execute(
            text("DO $$ BEGIN CREATE ROLE anon; EXCEPTION WHEN duplicate_object THEN NULL; END $$")
        )
        await connection.execute(
            text(
                "DO $$ BEGIN CREATE ROLE authenticated; "
                "EXCEPTION WHEN duplicate_object THEN NULL; END $$"
            )
        )

        def downgrade(sync_connection):
            with Operations.context(MigrationContext.configure(sync_connection)):
                migration["downgrade"]()

        await connection.run_sync(downgrade)
        await connection.execute(AUTH_USERS_TABLE.insert().values(id=user_id))
        await connection.execute(
            text(
                "INSERT INTO media_files "
                "(id, user_id, purpose, status, bucket_name, object_path, content_type) "
                "VALUES (:id, :user_id, 'CHAT', 'READY', 'leafie-media', :path, 'image/jpeg')"
            ),
            {"id": media_id, "user_id": user_id, "path": f"{user_id}/chat/{media_id}.jpg"},
        )

        def upgrade(sync_connection):
            with Operations.context(MigrationContext.configure(sync_connection)):
                migration["upgrade"]()

        await connection.run_sync(upgrade)
        table_names = await connection.run_sync(lambda conn: inspect(conn).get_table_names())
        remaining = await connection.scalar(
            text("SELECT count(*) FROM media_files WHERE id = :id"), {"id": media_id}
        )

    assert {
        "ai_conversations",
        "ai_messages",
        "ai_actions",
        "ai_tool_calls",
    }.isdisjoint(table_names)
    assert remaining == 0


@pytest.mark.parametrize("draw", [0, 600])
async def test_random_delay_boundaries(db, queue, monkeypatch, draw):
    monkeypatch.setattr("app.services.letter.secrets.randbelow", lambda bound: draw)
    before = datetime.now(UTC)
    _, _, _, letter_id = await seed(db, queue)
    after = datetime.now(UTC)
    scheduled = (await load(db, letter_id)).scheduled_at
    assert before + timedelta(seconds=300 + draw) <= scheduled
    assert scheduled <= after + timedelta(seconds=300 + draw)


async def test_concurrent_reservation_enqueues_once(db, queue):
    user, _, diary, _ = await seed(db, queue, reserve=False)

    async def reserve():
        async with db.session_context() as session:
            return (
                await reserve_letter(session, queue, user_id=user, diary_id=diary, created=True)
            ).id

    first, second = await asyncio.gather(reserve(), reserve())
    assert first == second
    async with db.session_context() as session:
        assert await session.scalar(text("SELECT count(*) FROM letter_test_queue")) == 1


async def test_same_timestamp_cursor_survives_previous_page_deletion(db, queue):
    user, plant, _, _ = await seed(db, queue, reserve=False)
    published = datetime.now(UTC) - timedelta(seconds=2)
    ids = sorted([uuid4() for _ in range(3)], reverse=True)
    async with db.session_context() as session:
        for index, letter_id in enumerate(ids):
            diary = PlantDiary(
                plant_id=plant,
                diary_date=date(2026, 8, index + 1),
                content="일기",
                weather="SUNNY",
                title="햇빛 좋은 날",
            )
            session.add(diary)
            await session.flush()
            session.add(
                Letter(
                    id=letter_id,
                    plant_id=plant,
                    diary_id=diary.id,
                    diary_date=diary.diary_date,
                    scheduled_at=published,
                    generated_at=published,
                    published_at=published,
                    status="COMPLETED",
                    content="편지",
                )
            )
    async with db.session_context() as session:
        service = LetterService(session)
        first = await service.list(user, limit=1)
        assert first.items[0].id == ids[0]
        await service.delete(user, ids[0])
        second = await service.list(user, limit=1, cursor=first.next_cursor)
        assert second.items[0].id == ids[1]
        third = await service.list(user, limit=1, cursor=second.next_cursor)
        assert third.items[0].id == ids[2]
        assert third.next_cursor is None


async def test_complete_and_publish_job_commit_together(db, queue):
    _, _, _, letter_id = await seed(db, queue)
    repo = SQLAlchemyLetterRepository(db, queue)
    work = await repo.start(letter_id)
    queue.fail = True
    with pytest.raises(RuntimeError):
        await repo.complete(letter_id, work.token, LetterCompletion("본문", "id", "model", 1, 2))
    assert (await load(db, letter_id)).status == "PROCESSING"
    assert (await load(db, letter_id)).content is None
    queue.fail = False
    await repo.complete(letter_id, work.token, LetterCompletion("본문", "id", "model", 1, 2))
    await repo.exhausted(letter_id)
    assert (await load(db, letter_id)).status == "COMPLETED"


async def test_exhaustion_keeps_active_claim_and_schedules_recovery(db, queue):
    _, _, _, letter_id = await seed(db, queue)
    repo = SQLAlchemyLetterRepository(db, queue)
    work = await repo.start(letter_id)
    await repo.exhausted(letter_id)
    assert (await load(db, letter_id)).lease_token == work.token
    async with db.session_context() as session:
        assert await session.scalar(text("SELECT count(*) FROM letter_test_queue")) == 2
        await session.execute(
            update(Letter)
            .where(Letter.id == letter_id)
            .values(lease_until=datetime.now(UTC) - timedelta(seconds=1))
        )
    await repo.exhausted(letter_id)
    assert (await load(db, letter_id)).status == "FAILED"


async def test_handler_timeout_releases_claim(db, queue):
    class SlowProvider(Provider):
        async def generate(self, snapshot, *, safety_user_id):
            await asyncio.sleep(10)

    _, _, _, letter_id = await seed(db, queue)
    handler = LetterGenerationHandler(
        SQLAlchemyLetterRepository(db, queue), SlowProvider(), Sensors(), timeout_seconds=0.05
    )
    with pytest.raises(RuntimeError):
        await handler(job(letter_id))
    assert (await load(db, letter_id)).status == "PENDING"


async def test_publication_failure_is_not_silently_archived(db, queue):
    handler = LetterPublishHandler(SQLAlchemyLetterRepository(db, queue))
    with pytest.raises(RuntimeError, match="PUBLICATION_REQUIRES_RETRY"):
        await handler.on_exhausted(job(uuid4()))


@pytest.mark.parametrize(
    "value", [[1, 2], ["2026-09-11T00:00:00+00:00", {}], ["2026-09-11T00:00:00", str(uuid4())]]
)
def test_cursor_rejects_wrong_types_or_naive_time(value):
    cursor = base64.urlsafe_b64encode(json.dumps(value).encode()).decode()
    with pytest.raises(AppError):
        decode_letter_cursor(cursor)


async def test_reservation_rejects_other_users_diary(db, queue):
    _, _, diary, _ = await seed(db, queue, reserve=False)
    other_user, _, _, _ = await seed(db, queue, reserve=False)
    async with db.session_context() as session:
        with pytest.raises(AppError) as caught:
            await reserve_letter(session, queue, user_id=other_user, diary_id=diary, created=True)
        assert caught.value.status_code == 404
        assert await session.scalar(select(func.count()).select_from(Letter)) == 0
        assert await session.scalar(text("SELECT count(*) FROM letter_test_queue")) == 0


@pytest.mark.parametrize("target", ["plant", "account", "diary"])
@pytest.mark.parametrize("published", [False, True])
async def test_deletion_after_generation_blocks_publication_or_pending_push(
    db, queue, target, published
):
    user, plant, diary, letter_id = await seed(db, queue)
    repo = SQLAlchemyLetterRepository(db, queue)
    await LetterGenerationHandler(repo, Provider(), Sensors())(job(letter_id))
    await make_due(db, letter_id)
    notification_id = None
    if published:
        await repo.publish(letter_id)
        async with db.session_context() as session:
            notification_id = await session.scalar(select(Notification.id))
    async with db.session_context() as session:
        if target == "plant":
            await session.execute(
                update(Plant).where(Plant.id == plant).values(deleted_at=datetime.now(UTC))
            )
        elif target == "account":
            await session.execute(
                update(UserProfile)
                .where(UserProfile.user_id == user)
                .values(deleted_at=datetime.now(UTC), deletion_status="PENDING")
            )
        else:
            await session.execute(delete(PlantDiary).where(PlantDiary.id == diary))
    await repo.publish(letter_id)
    async with db.session_context() as session:
        assert not (await LetterService(session).list(user)).items
        if not published:
            assert await session.scalar(select(func.count()).select_from(Notification)) == 0
    if notification_id:
        assert await SQLAlchemyPushRepository(db).load(notification_id) is None
