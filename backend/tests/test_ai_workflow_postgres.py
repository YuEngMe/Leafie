"""AI lifecycle regression tests on a disposable local database; no paid API calls."""

import asyncio
import hashlib
import os
from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import UUID, uuid4

import httpx
import pytest
from sqlalchemy import delete, func, select, text, update
from sqlalchemy.engine import make_url

from app.api.dependencies import (
    get_current_user,
    get_database_session,
    get_job_queue,
    get_storage_gateway,
)
from app.api.v1 import diagnoses as diagnosis_api
from app.core.config import Settings
from app.core.security import AuthenticatedUser
from app.db.base import AUTH_USERS_TABLE, Base
from app.db.session import Database
from app.integrations.diagnosis import DiagnosisImageQualityResult, DiagnosisProviderResult
from app.integrations.plantnet import PlantNetCandidate
from app.integrations.storage import StorageObjectInfo
from app.main import create_app
from app.models.diagnosis import Diagnosis
from app.models.media import MediaFile, SpeciesIdentification
from app.models.notification import Notification
from app.models.plant import Plant, SpeciesCareGuide
from app.models.user import UserProfile
from app.services.diagnosis import SQLAlchemyDiagnosisAPIRepository
from app.services.plant_management import SQLAlchemyPlantManagementRepository
from app.tasks.diagnosis import (
    DiagnosisHandler,
    SQLAlchemyDiagnosisRepository,
    build_recommended_care,
)
from app.tasks.species import SpeciesIdentificationHandler, SpeciesIdentificationRepository


@pytest.fixture
async def ai_db():
    url = os.environ.get("AI_TEST_DATABASE_URL")
    if not url:
        pytest.skip("Set AI_TEST_DATABASE_URL to a disposable local PostgreSQL database")
    parsed = make_url(url)
    if parsed.host not in ("127.0.0.1", "localhost") or parsed.database != "leafie_ai_test":
        pytest.fail("AI tests require a disposable localhost/leafie_ai_test database")
    database = Database(Settings(_env_file=None, database_url=url))
    async with database.engine.begin() as connection:
        await connection.execute(text("CREATE SCHEMA IF NOT EXISTS auth"))
        await connection.run_sync(Base.metadata.create_all)
    try:
        yield database
    finally:
        async with database.engine.begin() as connection:
            await connection.execute(delete(AUTH_USERS_TABLE))
            await connection.execute(delete(SpeciesCareGuide))
        await database.close()


async def seed(db):
    ids = SimpleNamespace(
        user=uuid4(),
        plant=uuid4(),
        media=uuid4(),
        species_media=uuid4(),
        diagnosis=uuid4(),
        identification=uuid4(),
    )
    async with db.session_context() as session:
        await session.execute(AUTH_USERS_TABLE.insert().values(id=ids.user))
        session.add(UserProfile(user_id=ids.user, nickname="test"))
        guide_id = str(uuid4())
        session.add(
            SpeciesCareGuide(
                species_reference_id=guide_id,
                display_name="Basil",
                category="HERB",
                scientific_name="Ocimum basilicum",
                gbif_id=2927096,
            )
        )
        await session.flush()
        session.add(
            Plant(
                id=ids.plant,
                user_id=ids.user,
                species_reference_id=guide_id,
                nickname="Basil",
                client_registration_id=uuid4(),
                registration_request_hash="a" * 64,
                species_selection_method="SEARCH",
                started_on=date(2026, 1, 1),
                place_name="home",
                personality_type="INTROVERTED",
                body_id="body_circle",
                color_id="color_green",
                hair_id="hair_sprout",
                expression_id="expression_default",
            )
        )
        for media_id, purpose in (
            (ids.media, "DIAGNOSIS"),
            (ids.species_media, "SPECIES_IDENTIFICATION"),
        ):
            session.add(
                MediaFile(
                    id=media_id,
                    user_id=ids.user,
                    purpose=purpose,
                    status="READY",
                    bucket_name="test",
                    object_path=f"{ids.user}/{media_id}.png",
                    content_type="image/png",
                )
            )
        await session.flush()
        session.add(
            Diagnosis(
                id=ids.diagnosis, plant_id=ids.plant, media_file_id=ids.media, status="PENDING"
            )
        )
        session.add(
            SpeciesIdentification(
                id=ids.identification,
                user_id=ids.user,
                media_file_id=ids.species_media,
                status="PENDING",
            )
        )
    return ids


async def invalidate(db, ids, target):
    async with db.session_context() as session:
        now = datetime.now(UTC)
        if target == "plant":
            await session.execute(update(Plant).where(Plant.id == ids.plant).values(deleted_at=now))
        elif target == "account":
            await session.execute(
                update(UserProfile)
                .where(UserProfile.user_id == ids.user)
                .values(deleted_at=now, deletion_status="PENDING")
            )
        elif target == "deletion_failed":
            await session.execute(
                update(UserProfile)
                .where(UserProfile.user_id == ids.user)
                .values(deleted_at=now, deletion_status="FAILED")
            )
        else:
            await session.execute(
                update(MediaFile)
                .where(MediaFile.user_id == ids.user)
                .values(status="DELETED", deleted_at=now)
            )


def result():
    return DiagnosisProviderResult(
        overall_condition="HEALTHY",
        condition_label="Healthy",
        observations=["No visible issues"],
        possible_causes=[],
        provider_name="test",
        model_name="test",
    )


def quality():
    return DiagnosisImageQualityResult(
        acceptable=True,
        plant_visible=True,
        sharp_enough=True,
        brightness_acceptable=True,
        symptom_area_visible=True,
    )


@pytest.mark.parametrize("target", ["plant", "account", "deletion_failed", "media"])
async def test_diagnosis_does_not_start_for_deleted_sources(ai_db, target):
    ids = await seed(ai_db)
    await invalidate(ai_db, ids, target)
    repo = SQLAlchemyDiagnosisRepository(ai_db, SimpleNamespace(enqueue=AsyncMock()))
    assert await repo.start(ids.diagnosis) is None


@pytest.mark.parametrize("target", ["plant", "account", "deletion_failed", "media"])
async def test_late_diagnosis_result_cannot_publish_after_deletion(ai_db, target):
    ids = await seed(ai_db)
    queue = SimpleNamespace(enqueue=AsyncMock())
    repo = SQLAlchemyDiagnosisRepository(ai_db, queue)
    assert await repo.start(ids.diagnosis) is not None
    await invalidate(ai_db, ids, target)
    await repo.complete(ids.diagnosis, quality(), result(), ["Keep current care"])
    async with ai_db.session_context() as session:
        diagnosis = await session.get(Diagnosis, ids.diagnosis)
        assert diagnosis.status != "COMPLETED"
        assert diagnosis.observations is None
        assert await session.scalar(select(func.count()).select_from(Notification)) == 0
    queue.enqueue.assert_not_awaited()


@pytest.mark.parametrize("target", ["account", "deletion_failed", "media"])
async def test_species_does_not_start_for_deleted_sources(ai_db, target):
    ids = await seed(ai_db)
    await invalidate(ai_db, ids, target)
    assert await SpeciesIdentificationRepository(ai_db).start(ids.identification) is None


@pytest.mark.parametrize("target", ["account", "deletion_failed", "media"])
async def test_late_species_result_cannot_complete_after_deletion(ai_db, target):
    ids = await seed(ai_db)
    repo = SpeciesIdentificationRepository(ai_db)
    assert await repo.start(ids.identification) is not None
    await invalidate(ai_db, ids, target)
    await repo.complete(ids.identification, [])
    async with ai_db.session_context() as session:
        item = await session.get(SpeciesIdentification, ids.identification)
        assert item.status != "COMPLETED"
        assert item.candidates is None


async def test_diagnosis_completion_and_notification_are_idempotent(ai_db):
    ids = await seed(ai_db)
    queue = SimpleNamespace(enqueue=AsyncMock())
    repo = SQLAlchemyDiagnosisRepository(ai_db, queue)
    assert await repo.start(ids.diagnosis) is not None
    for _ in range(2):
        await repo.complete(ids.diagnosis, quality(), result(), ["Keep current care"])
    async with ai_db.session_context() as session:
        assert (await session.get(Diagnosis, ids.diagnosis)).status == "COMPLETED"
        assert await session.scalar(select(func.count()).select_from(Notification)) == 1
    queue.enqueue.assert_awaited_once()


async def test_diagnosis_queue_failure_rolls_back_result_and_notification(ai_db):
    ids = await seed(ai_db)
    queue = SimpleNamespace(enqueue=AsyncMock(side_effect=RuntimeError("queue failed")))
    repo = SQLAlchemyDiagnosisRepository(ai_db, queue)
    await repo.start(ids.diagnosis)
    with pytest.raises(RuntimeError, match="queue failed"):
        await repo.complete(ids.diagnosis, quality(), result(), ["Keep current care"])
    async with ai_db.session_context() as session:
        assert (await session.get(Diagnosis, ids.diagnosis)).status == "PROCESSING"
        assert await session.scalar(select(func.count()).select_from(Notification)) == 0


async def test_deletion_lock_wins_over_late_diagnosis_completion(ai_db):
    ids = await seed(ai_db)
    queue = SimpleNamespace(enqueue=AsyncMock())
    repo = SQLAlchemyDiagnosisRepository(ai_db, queue)
    await repo.start(ids.diagnosis)
    async with ai_db.session_context() as session:
        deleting = SQLAlchemyPlantManagementRepository(session)
        await deleting.get_profile(ids.user, lock=True)
        plant = await deleting.get_plant_for_delete(ids.user, ids.plant)
        plant.deleted_at = datetime.now(UTC)
        await session.flush()
        completion = asyncio.create_task(
            repo.complete(ids.diagnosis, quality(), result(), ["Keep current care"])
        )
        try:
            await asyncio.sleep(0.05)
            assert not completion.done()
        finally:
            # Release the deletion transaction before waiting for the blocked worker.
            await session.commit()
            await asyncio.wait_for(completion, timeout=5)
    queue.enqueue.assert_not_awaited()
    async with ai_db.session_context() as session:
        assert (await session.get(Diagnosis, ids.diagnosis)).status != "COMPLETED"


async def test_retry_repository_rejects_deleted_account(ai_db):
    ids = await seed(ai_db)
    await invalidate(ai_db, ids, "account")
    async with ai_db.session_context() as session:
        repository = SQLAlchemyDiagnosisAPIRepository(session)
        assert await repository.get_owned(ids.diagnosis, ids.user, lock=True) is None


@pytest.mark.parametrize("kind", ["diagnosis", "species"])
async def test_photo_api_worker_result_and_ownership_flow(ai_db, monkeypatch, kind):
    """Real HTTP routes and DB, mocked Storage/Queue/Provider; never calls paid services."""
    ids = await seed(ai_db)
    monkeypatch.setattr(diagnosis_api.settings, "kindwise_api_key", "test-only")
    image = b"\x89PNG\r\n\x1a\n" + b"0" * 1024
    storage = SimpleNamespace(
        bucket_name="test",
        create_signed_upload_url=AsyncMock(return_value="https://storage.test/upload"),
        get_object_info=AsyncMock(
            return_value=StorageObjectInfo(size_bytes=len(image), content_type="image/png")
        ),
        download_object=AsyncMock(return_value=image),
        create_signed_download_url=AsyncMock(return_value="https://storage.test/photo"),
    )
    queue = SimpleNamespace(enqueue=AsyncMock(return_value=1))
    app = create_app()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=ids.user, email=None, role=None, claims={}
    )
    app.dependency_overrides[get_database_session] = ai_db.session
    app.dependency_overrides[get_storage_gateway] = lambda: storage
    app.dependency_overrides[get_job_queue] = lambda: queue
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://test"
    ) as client:
        upload = await client.post(
            "/api/v1/media/presign",
            json={
                "purpose": "DIAGNOSIS" if kind == "diagnosis" else "SPECIES_IDENTIFICATION",
                "content_type": "image/png",
                "size_bytes": len(image),
                "checksum_sha256": hashlib.sha256(image).hexdigest(),
            },
        )
        assert upload.status_code == 201, upload.text
        media_id = upload.json()["media_file_id"]
        complete = await client.post(f"/api/v1/media/{media_id}/complete")
        assert complete.status_code == 200, complete.text
        create_path = (
            f"/api/v1/plants/{ids.plant}/diagnoses"
            if kind == "diagnosis"
            else "/api/v1/species/identifications"
        )
        response = await client.post(create_path, json={"media_file_id": media_id})
        assert response.status_code == 202, response.text
        key = "diagnosis_id" if kind == "diagnosis" else "identification_id"
        resource_id = response.json()[key]
        repeated = await client.post(create_path, json={"media_file_id": media_id})
        assert repeated.json()[key] == resource_id
        queue.enqueue.assert_awaited_once()
        job = queue.enqueue.call_args.args[0]
        assert job.resource_id == UUID(resource_id)
        if kind == "diagnosis":
            provider = SimpleNamespace(diagnose=AsyncMock(return_value=result()))
            handler = DiagnosisHandler(
                SQLAlchemyDiagnosisRepository(ai_db, queue),
                storage,
                SimpleNamespace(check=AsyncMock(return_value=quality())),
                provider,
                build_recommended_care,
            )
            detail_path = f"/api/v1/diagnoses/{resource_id}"
        else:
            provider = SimpleNamespace(
                identify=AsyncMock(
                    return_value=[
                        PlantNetCandidate(
                            scientific_name="Ocimum basilicum",
                            common_names=("Basil",),
                            confidence=0.87,
                            gbif_id=2927096,
                        )
                    ]
                )
            )
            handler = SpeciesIdentificationHandler(
                SpeciesIdentificationRepository(ai_db), storage, provider
            )
            detail_path = f"/api/v1/species/identifications/{resource_id}"
        await handler(job)
        await handler(job)
        detail = await client.get(detail_path)
        assert detail.status_code == 200, detail.text
        assert detail.json()["status"] == "COMPLETED"
        if kind == "diagnosis":
            provider.diagnose.assert_awaited_once()
            assert detail.json()["overall_condition"] == "HEALTHY"
            assert detail.json()["possible_causes"] == []
            assert detail.json()["recommended_care"]
            assert "condition_score" not in detail.json()
        else:
            provider.identify.assert_awaited_once()
            assert detail.json()["candidates"][0]["scientific_name"] == "Ocimum basilicum"
            assert detail.json()["candidates"][0]["confidence"] == 0.87
        app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
            id=uuid4(), email=None, role=None, claims={}
        )
        assert (await client.get(detail_path)).status_code == 404
        assert (await client.post(create_path, json={"media_file_id": media_id})).status_code == 404
