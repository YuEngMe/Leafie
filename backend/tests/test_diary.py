from collections.abc import Iterator
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.dependencies import (
    get_current_user,
    get_database_session,
    get_job_queue,
    get_storage_gateway,
)
from app.api.v1 import diaries as diaries_api
from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.enums import MediaPurpose, MediaStatus
from app.models.media import MediaFile
from app.models.plant import PlantDiary
from app.schemas.diary import DiaryUpsertRequest
from app.schemas.queue import JobType, QueueJob
from app.services.diary import (
    DiaryService,
    OwnedPlantContext,
    average_condition_level,
    condition_level,
    monthly_statistics,
    today_in_timezone,
)


class FakeDiaryRepository:
    def __init__(self, user_id: UUID, plant_id: UUID) -> None:
        self.user_id = user_id
        self.plant_id = plant_id
        self.timezone = "Asia/Seoul"
        self.diaries: dict[date, PlantDiary] = {}
        self.media: dict[UUID, MediaFile] = {}
        self.flush_count = 0

    async def get_owned_plant_context(
        self,
        plant_id: UUID,
        user_id: UUID,
        *,
        lock: bool = False,
    ) -> OwnedPlantContext | None:
        if plant_id != self.plant_id or user_id != self.user_id:
            return None
        return OwnedPlantContext(plant_id=plant_id, timezone=self.timezone)

    async def get_diary(
        self,
        plant_id: UUID,
        diary_date: date,
        *,
        lock: bool = False,
    ) -> PlantDiary | None:
        if plant_id != self.plant_id:
            return None
        return self.diaries.get(diary_date)

    async def list_diaries(
        self,
        plant_id: UUID,
        start_date: date,
        end_date: date,
    ) -> list[PlantDiary]:
        if plant_id != self.plant_id:
            return []
        return sorted(
            (diary for diary in self.diaries.values() if start_date <= diary.diary_date < end_date),
            key=lambda diary: diary.diary_date,
        )

    async def average_condition_score(
        self,
        plant_id: UUID,
        start_date: date,
        end_date: date,
    ) -> Decimal | None:
        diaries = await self.list_diaries(plant_id, start_date, end_date)
        if not diaries:
            return None
        return Decimal(sum(diary.condition_score for diary in diaries)) / Decimal(len(diaries))

    async def get_media(
        self,
        media_file_id: UUID,
        user_id: UUID,
        *,
        lock: bool = False,
    ) -> MediaFile | None:
        media_file = self.media.get(media_file_id)
        if media_file is None or media_file.user_id != user_id:
            return None
        return media_file

    async def media_is_used_by_other_diary(
        self,
        media_file_id: UUID,
        diary_id: UUID | None,
    ) -> bool:
        return any(
            diary.media_file_id == media_file_id and diary.id != diary_id
            for diary in self.diaries.values()
        )

    async def add_diary(self, diary: PlantDiary) -> None:
        self.diaries[diary.diary_date] = diary

    async def delete_diary(self, diary: PlantDiary) -> None:
        self.diaries.pop(diary.diary_date, None)

    async def flush(self) -> None:
        self.flush_count += 1


class FakeStorage:
    bucket_name = "leafie-media"

    def __init__(self) -> None:
        self.download_requests: list[tuple[str, int]] = []

    async def create_signed_download_url(
        self,
        object_path: str,
        *,
        expires_in: int,
    ) -> str:
        self.download_requests.append((object_path, expires_in))
        return f"https://storage.example/{object_path}"


class FakeQueue:
    def __init__(self) -> None:
        self.jobs: list[QueueJob] = []
        self.sessions: list[object] = []

    async def enqueue(
        self,
        job: QueueJob,
        *,
        delay_seconds: int = 0,
        session=None,
    ) -> int:
        self.jobs.append(job)
        self.sessions.append(session)
        return len(self.jobs)


def make_request(**overrides: object) -> DiaryUpsertRequest:
    payload: dict[str, object] = {
        "content": "오늘 새잎이 자랐다.",
        "condition_score": 75,
    }
    payload.update(overrides)
    return DiaryUpsertRequest.model_validate(payload)


def make_media(
    user_id: UUID,
    *,
    purpose: MediaPurpose = MediaPurpose.DIARY,
    status: MediaStatus = MediaStatus.READY,
) -> MediaFile:
    media_file_id = uuid4()
    return MediaFile(
        id=media_file_id,
        user_id=user_id,
        purpose=purpose.value,
        status=status.value,
        bucket_name="leafie-media",
        object_path=f"{user_id}/diary/{media_file_id}.jpg",
        content_type="image/jpeg",
        size_bytes=1024,
    )


def build_service() -> tuple[
    DiaryService,
    FakeDiaryRepository,
    FakeStorage,
    UUID,
    UUID,
]:
    user_id = uuid4()
    plant_id = uuid4()
    repository = FakeDiaryRepository(user_id, plant_id)
    storage = FakeStorage()
    return DiaryService(repository, storage), repository, storage, user_id, plant_id


def test_diary_schema_accepts_only_confirmed_scores_and_two_thousand_characters() -> None:
    assert make_request(content="  기록  ").content == "기록"
    assert len(make_request(content=f"  {'가' * 2000}  ").content) == 2000

    for score in (0, 25, 50, 75, 100):
        assert make_request(condition_score=score).condition_score == score

    for invalid_score in (20, 75.0, True, "75"):
        with pytest.raises(ValidationError):
            make_request(condition_score=invalid_score)
    with pytest.raises(ValidationError):
        make_request(content=" " * 10)
    for whitespace_only in ("\t", "\n", "\r\n", "\f", "\v", " \t\n\r\f\v "):
        with pytest.raises(ValidationError):
            make_request(content=whitespace_only)
    with pytest.raises(ValidationError):
        make_request(content="가" * 2001)


async def test_create_diary_without_photo() -> None:
    service, repository, _, user_id, plant_id = build_service()
    diary_date = today_in_timezone(repository.timezone)

    result = await service.upsert_diary(user_id, plant_id, diary_date, make_request())

    assert result.created is True
    assert result.cleanup_media_ids == ()
    assert result.response.plant_id == plant_id
    assert result.response.diary_date == diary_date
    assert result.response.condition_score == 75
    assert result.response.condition_level == 4
    assert result.response.media is None
    assert len(repository.diaries) == 1


async def test_future_diary_is_rejected() -> None:
    service, repository, _, user_id, plant_id = build_service()
    tomorrow = today_in_timezone(repository.timezone) + timedelta(days=1)

    with pytest.raises(AppError) as error:
        await service.upsert_diary(user_id, plant_id, tomorrow, make_request())

    assert error.value.code == "FUTURE_DATE_NOT_ALLOWED"
    assert repository.diaries == {}


async def test_photo_diary_returns_signed_url() -> None:
    service, repository, storage, user_id, plant_id = build_service()
    media_file = make_media(user_id)
    repository.media[media_file.id] = media_file

    result = await service.upsert_diary(
        user_id,
        plant_id,
        date(2026, 7, 1),
        make_request(media_file_id=media_file.id),
    )

    assert result.response.media is not None
    assert result.response.media.id == media_file.id
    assert result.response.media.download_url.endswith(media_file.object_path)
    assert storage.download_requests == [(media_file.object_path, 300)]


@pytest.mark.parametrize("media_state", ["missing", "deleted"])
async def test_detail_omits_unavailable_photo_but_keeps_diary(media_state: str) -> None:
    service, repository, storage, user_id, plant_id = build_service()
    media_file = make_media(user_id)
    if media_state == "deleted":
        media_file.status = MediaStatus.DELETED.value
        media_file.deleted_at = datetime.now(UTC)
        repository.media[media_file.id] = media_file
    now = datetime.now(UTC)
    diary = PlantDiary(
        id=uuid4(),
        plant_id=plant_id,
        media_file_id=media_file.id,
        diary_date=date(2026, 7, 1),
        content="사진 없이도 남아야 하는 기록",
        condition_score=75,
        created_at=now,
        updated_at=now,
    )
    repository.diaries[diary.diary_date] = diary

    response = await service.get_diary(user_id, plant_id, diary.diary_date)

    assert response.content == diary.content
    assert response.condition_score == 75
    assert response.media is None
    assert storage.download_requests == []


@pytest.mark.parametrize(
    ("configure", "error_code"),
    [
        ("missing", "MEDIA_FILE_NOT_FOUND"),
        ("other_user", "MEDIA_FILE_NOT_FOUND"),
        ("purpose", "MEDIA_PURPOSE_MISMATCH"),
        ("pending", "MEDIA_NOT_READY"),
        ("deleted", "MEDIA_FILE_NOT_FOUND"),
    ],
)
async def test_diary_photo_requires_owned_ready_diary_media(
    configure: str,
    error_code: str,
) -> None:
    service, repository, _, user_id, plant_id = build_service()
    media_file = make_media(user_id)
    if configure != "missing":
        repository.media[media_file.id] = media_file
    if configure == "other_user":
        media_file.user_id = uuid4()
    elif configure == "purpose":
        media_file.purpose = MediaPurpose.CHAT.value
    elif configure == "pending":
        media_file.status = MediaStatus.PENDING.value
    elif configure == "deleted":
        media_file.status = MediaStatus.DELETED.value
        media_file.deleted_at = datetime.now(UTC)

    with pytest.raises(AppError) as error:
        await service.upsert_diary(
            user_id,
            plant_id,
            date(2026, 7, 1),
            make_request(media_file_id=media_file.id),
        )

    assert error.value.code == error_code
    assert repository.diaries == {}


async def test_omitted_photo_keeps_existing_photo_on_update() -> None:
    service, repository, _, user_id, plant_id = build_service()
    media_file = make_media(user_id)
    repository.media[media_file.id] = media_file
    diary_date = date(2026, 7, 1)
    await service.upsert_diary(
        user_id,
        plant_id,
        diary_date,
        make_request(media_file_id=media_file.id),
    )

    result = await service.upsert_diary(
        user_id,
        plant_id,
        diary_date,
        make_request(content="수정한 기록", condition_score=100),
    )

    assert result.created is False
    assert result.cleanup_media_ids == ()
    assert result.response.media is not None
    assert result.response.media.id == media_file.id
    assert repository.diaries[diary_date].media_file_id == media_file.id
    assert media_file.status == MediaStatus.READY


async def test_resending_current_photo_keeps_it_active() -> None:
    service, repository, _, user_id, plant_id = build_service()
    media_file = make_media(user_id)
    repository.media[media_file.id] = media_file
    diary_date = date(2026, 7, 1)
    request = make_request(media_file_id=media_file.id)
    await service.upsert_diary(user_id, plant_id, diary_date, request)

    result = await service.upsert_diary(user_id, plant_id, diary_date, request)

    assert result.created is False
    assert result.cleanup_media_ids == ()
    assert media_file.status == MediaStatus.READY
    assert media_file.deleted_at is None


async def test_explicit_null_removes_and_soft_deletes_existing_photo() -> None:
    service, repository, _, user_id, plant_id = build_service()
    media_file = make_media(user_id)
    repository.media[media_file.id] = media_file
    diary_date = date(2026, 7, 1)
    await service.upsert_diary(
        user_id,
        plant_id,
        diary_date,
        make_request(media_file_id=media_file.id),
    )

    result = await service.upsert_diary(
        user_id,
        plant_id,
        diary_date,
        make_request(media_file_id=None),
    )

    assert result.response.media is None
    assert result.cleanup_media_ids == (media_file.id,)
    assert repository.diaries[diary_date].media_file_id is None
    assert media_file.status == MediaStatus.DELETED
    assert media_file.deleted_at is not None


async def test_replacing_photo_deletes_old_and_links_new_photo() -> None:
    service, repository, _, user_id, plant_id = build_service()
    old_media = make_media(user_id)
    new_media = make_media(user_id)
    repository.media[old_media.id] = old_media
    repository.media[new_media.id] = new_media
    diary_date = date(2026, 7, 1)
    await service.upsert_diary(
        user_id,
        plant_id,
        diary_date,
        make_request(media_file_id=old_media.id),
    )

    result = await service.upsert_diary(
        user_id,
        plant_id,
        diary_date,
        make_request(media_file_id=new_media.id),
    )

    assert result.cleanup_media_ids == (old_media.id,)
    assert result.response.media is not None
    assert result.response.media.id == new_media.id
    assert old_media.status == MediaStatus.DELETED
    assert new_media.status == MediaStatus.READY


async def test_same_media_cannot_be_shared_by_multiple_diaries() -> None:
    service, repository, _, user_id, plant_id = build_service()
    media_file = make_media(user_id)
    repository.media[media_file.id] = media_file
    await service.upsert_diary(
        user_id,
        plant_id,
        date(2026, 7, 1),
        make_request(media_file_id=media_file.id),
    )

    with pytest.raises(AppError) as error:
        await service.upsert_diary(
            user_id,
            plant_id,
            date(2026, 7, 2),
            make_request(media_file_id=media_file.id),
        )

    assert error.value.code == "MEDIA_FILE_IN_USE"
    assert len(repository.diaries) == 1


async def test_month_list_returns_integer_average_and_midpoint_level() -> None:
    service, repository, _, user_id, plant_id = build_service()
    await service.upsert_diary(
        user_id,
        plant_id,
        date(2026, 7, 1),
        make_request(condition_score=25),
    )
    await service.upsert_diary(
        user_id,
        plant_id,
        date(2026, 7, 2),
        make_request(condition_score=50),
    )
    await service.upsert_diary(
        user_id,
        plant_id,
        date(2026, 8, 1),
        make_request(condition_score=100),
    )

    response = await service.list_month(user_id, plant_id, 2026, 7)

    assert [entry.diary_date for entry in response.entries] == [
        date(2026, 7, 1),
        date(2026, 7, 2),
    ]
    assert response.statistics.entry_count == 2
    assert response.statistics.average_score == 38
    assert response.statistics.average_level == 3


async def test_empty_month_returns_null_average() -> None:
    service, _, _, user_id, plant_id = build_service()

    response = await service.list_month(user_id, plant_id, 2026, 7)

    assert response.entries == []
    assert response.statistics.entry_count == 0
    assert response.statistics.average_score is None
    assert response.statistics.average_level is None


async def test_delete_diary_is_idempotent_and_marks_photo_for_cleanup() -> None:
    service, repository, _, user_id, plant_id = build_service()
    media_file = make_media(user_id)
    repository.media[media_file.id] = media_file
    diary_date = date(2026, 7, 1)
    await service.upsert_diary(
        user_id,
        plant_id,
        diary_date,
        make_request(media_file_id=media_file.id),
    )

    first = await service.delete_diary(user_id, plant_id, diary_date)
    second = await service.delete_diary(user_id, plant_id, diary_date)

    assert first.cleanup_media_ids == (media_file.id,)
    assert second.cleanup_media_ids == ()
    assert diary_date not in repository.diaries
    assert media_file.status == MediaStatus.DELETED


async def test_diary_access_is_scoped_to_owned_plant() -> None:
    service, _, _, user_id, plant_id = build_service()

    with pytest.raises(AppError) as error:
        await service.list_month(uuid4(), plant_id, 2026, 7)

    assert error.value.code == "PLANT_NOT_FOUND"
    assert error.value.status_code == 404


def test_condition_level_helpers_use_confirmed_boundaries() -> None:
    assert [condition_level(score) for score in (0, 25, 50, 75, 100)] == [1, 2, 3, 4, 5]
    assert average_condition_level(Decimal("12.49")) == 1
    assert average_condition_level(Decimal("12.5")) == 2
    assert average_condition_level(Decimal("37.5")) == 3
    assert average_condition_level(Decimal("62.5")) == 4
    assert average_condition_level(Decimal("87.5")) == 5
    assert monthly_statistics(2, Decimal("37.5")).average_score == 38


@pytest.mark.parametrize("invalid_timezone", ["", "/invalid/timezone"])
def test_invalid_timezone_format_falls_back_to_seoul(invalid_timezone: str) -> None:
    assert today_in_timezone(invalid_timezone) == datetime.now(ZoneInfo("Asia/Seoul")).date()


def test_diary_http_put_returns_created_then_ok(monkeypatch: pytest.MonkeyPatch) -> None:
    service, _, storage, user_id, plant_id = build_service()
    queue = FakeQueue()

    def fake_session() -> Iterator[object]:
        yield object()

    application = create_app()
    application.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=user_id,
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )
    application.dependency_overrides[get_database_session] = fake_session
    application.dependency_overrides[get_storage_gateway] = lambda: storage
    application.dependency_overrides[get_job_queue] = lambda: queue
    monkeypatch.setattr(diaries_api, "build_service", lambda _session, _storage: service)
    payload = make_request().model_dump(mode="json", exclude_unset=True)

    with TestClient(application) as client:
        first = client.put(f"/api/v1/plants/{plant_id}/diaries/2026-07-01", json=payload)
        second = client.put(f"/api/v1/plants/{plant_id}/diaries/2026-07-01", json=payload)

    assert first.status_code == 201
    assert second.status_code == 200
    assert second.json() == first.json()
    assert queue.jobs == []


def test_diary_http_list_detail_and_delete(monkeypatch: pytest.MonkeyPatch) -> None:
    service, repository, storage, user_id, plant_id = build_service()
    queue = FakeQueue()
    session = object()
    media_file = make_media(user_id)
    repository.media[media_file.id] = media_file
    now = datetime.now(UTC)
    diary = PlantDiary(
        id=uuid4(),
        plant_id=plant_id,
        media_file_id=media_file.id,
        diary_date=date(2026, 7, 1),
        content="상세 기록",
        condition_score=75,
        created_at=now,
        updated_at=now,
    )
    repository.diaries[diary.diary_date] = diary

    def fake_session() -> Iterator[object]:
        yield session

    application = create_app()
    application.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        id=user_id,
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )
    application.dependency_overrides[get_database_session] = fake_session
    application.dependency_overrides[get_storage_gateway] = lambda: storage
    application.dependency_overrides[get_job_queue] = lambda: queue
    monkeypatch.setattr(diaries_api, "build_service", lambda _session, _storage: service)

    with TestClient(application) as client:
        month = client.get(
            f"/api/v1/plants/{plant_id}/diaries",
            params={"year": 2026, "month": 7},
        )
        detail = client.get(f"/api/v1/plants/{plant_id}/diaries/2026-07-01")
        deleted = client.delete(f"/api/v1/plants/{plant_id}/diaries/2026-07-01")
        missing = client.get(f"/api/v1/plants/{plant_id}/diaries/2026-07-01")

    assert month.status_code == 200
    assert month.json()["statistics"] == {
        "entry_count": 1,
        "average_score": 75,
        "average_level": 4,
    }
    assert detail.status_code == 200
    assert detail.json()["media"]["id"] == str(media_file.id)
    assert deleted.status_code == 204
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "DIARY_NOT_FOUND"
    assert queue.sessions == [session]
    assert queue.jobs[0].resource_id == media_file.id


async def test_cleanup_jobs_use_same_database_transaction() -> None:
    queue = FakeQueue()
    session = object()
    media_file_id = uuid4()

    await diaries_api.enqueue_media_cleanup((media_file_id,), session, queue)

    assert queue.sessions == [session]
    assert queue.jobs[0].job_type == JobType.STORAGE_OBJECT_DELETE
    assert queue.jobs[0].resource_id == media_file_id
