from uuid import UUID, uuid4

import pytest

from app.models.enums import MediaPurpose, MediaStatus
from app.models.media import MediaFile
from app.schemas.queue import JobType, QueueJob
from app.tasks.base import PermanentTaskError
from app.tasks.storage import StorageObjectDeleteHandler


class FakeRepository:
    def __init__(self, media_file: MediaFile | None) -> None:
        self.media_file = media_file

    async def get(self, media_file_id: UUID) -> MediaFile | None:
        if self.media_file and self.media_file.id == media_file_id:
            return self.media_file
        return None


class FakeStorage:
    bucket_name = "leafie-media"

    def __init__(self) -> None:
        self.deleted: list[str] = []

    async def delete_object(self, object_path: str) -> None:
        self.deleted.append(object_path)


def make_media(status: MediaStatus = MediaStatus.DELETED) -> MediaFile:
    return MediaFile(
        id=uuid4(),
        user_id=uuid4(),
        purpose=MediaPurpose.DIAGNOSIS,
        status=status,
        bucket_name="leafie-media",
        object_path=f"test/{uuid4()}.jpg",
        content_type="image/jpeg",
        size_bytes=10,
    )


def make_job(resource_id: UUID) -> QueueJob:
    return QueueJob(
        job_type=JobType.STORAGE_OBJECT_DELETE,
        resource_id=resource_id,
        trace_id="req_storage_delete_test",
    )


async def test_storage_delete_removes_soft_deleted_object() -> None:
    media_file = make_media()
    storage = FakeStorage()
    handler = StorageObjectDeleteHandler(FakeRepository(media_file), storage)

    await handler(make_job(media_file.id))

    assert storage.deleted == [media_file.object_path]


async def test_storage_delete_missing_record_is_idempotent_success() -> None:
    storage = FakeStorage()
    handler = StorageObjectDeleteHandler(FakeRepository(None), storage)

    await handler(make_job(uuid4()))

    assert storage.deleted == []


async def test_storage_delete_rejects_active_media() -> None:
    media_file = make_media(MediaStatus.READY)
    storage = FakeStorage()
    handler = StorageObjectDeleteHandler(FakeRepository(media_file), storage)

    with pytest.raises(PermanentTaskError) as error:
        await handler(make_job(media_file.id))

    assert error.value.failure_code == "MEDIA_NOT_DELETED"
    assert storage.deleted == []
