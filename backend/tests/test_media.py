import hashlib
from datetime import UTC
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.v1.media import delete_media
from app.core.errors import AppError
from app.core.request_context import reset_request_id, set_request_id
from app.core.security import AuthenticatedUser
from app.integrations.storage import StorageObjectInfo
from app.main import create_app
from app.models.enums import MediaPurpose, MediaStatus
from app.models.media import MediaFile
from app.schemas.media import MediaPresignRequest
from app.schemas.queue import JobType, QueueJob
from app.services.media import MediaService

JPEG_BYTES = b"\xff\xd8\xff" + (b"\x00" * 1021)
CHECKSUM = hashlib.sha256(JPEG_BYTES).hexdigest()


class FakeMediaRepository:
    def __init__(self) -> None:
        self.items: dict[UUID, MediaFile] = {}

    async def add(self, media_file: MediaFile) -> None:
        self.items[media_file.id] = media_file

    async def get_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None:
        media_file = self.items.get(media_file_id)
        if media_file is None or media_file.user_id != user_id or media_file.deleted_at is not None:
            return None
        return media_file


class FakeStorageGateway:
    bucket_name = "leafie-media"

    def __init__(self) -> None:
        self.upload_paths: list[str] = []
        self.download_requests: list[tuple[str, int]] = []
        self.deleted_paths: list[str] = []
        self.object_info = StorageObjectInfo(size_bytes=1024, content_type="image/jpeg")
        self.object_bytes = JPEG_BYTES

    async def create_signed_upload_url(self, object_path: str) -> str:
        self.upload_paths.append(object_path)
        return f"https://storage.example/upload/{object_path}"

    async def get_object_info(self, _object_path: str) -> StorageObjectInfo:
        return self.object_info

    async def download_object(self, _object_path: str) -> bytes:
        return self.object_bytes

    async def create_signed_download_url(
        self,
        object_path: str,
        *,
        expires_in: int,
    ) -> str:
        self.download_requests.append((object_path, expires_in))
        return f"https://storage.example/download/{object_path}"

    async def delete_object(self, object_path: str) -> None:
        self.deleted_paths.append(object_path)


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


class FakeSession:
    def __init__(self, media_file: MediaFile) -> None:
        self.media_file = media_file

    async def scalar(self, _statement) -> MediaFile:
        return self.media_file


def build_request(**overrides: object) -> MediaPresignRequest:
    values = {
        "purpose": MediaPurpose.DIAGNOSIS,
        "file_name": "../../unsafe-name.exe",
        "content_type": "image/jpeg",
        "size_bytes": 1024,
        "checksum_sha256": CHECKSUM,
    }
    values.update(overrides)
    return MediaPresignRequest.model_validate(values)


def build_service(
    *,
    download_url_expires_seconds: int = 300,
) -> tuple[MediaService, FakeMediaRepository, FakeStorageGateway]:
    repository = FakeMediaRepository()
    storage = FakeStorageGateway()
    return (
        MediaService(
            repository,
            storage,
            download_url_expires_seconds=download_url_expires_seconds,
        ),
        repository,
        storage,
    )


async def test_presign_uses_server_generated_owned_path() -> None:
    service, repository, storage = build_service()
    user_id = uuid4()

    response = await service.create_upload(user_id, build_request())
    media_file = repository.items[response.media_file_id]

    assert media_file.object_path.startswith(f"{user_id}/diagnosis/")
    assert media_file.object_path.endswith(".jpg")
    assert "unsafe-name" not in media_file.object_path
    assert media_file.status == MediaStatus.PENDING
    assert media_file.checksum_sha256 == CHECKSUM
    assert storage.upload_paths == [media_file.object_path]
    assert response.expires_at.tzinfo == UTC


async def test_presign_rejects_purpose_size_limit() -> None:
    service, repository, storage = build_service()

    with pytest.raises(AppError) as error:
        await service.create_upload(
            uuid4(),
            build_request(
                purpose=MediaPurpose.USER_PROFILE,
                size_bytes=5 * 1024 * 1024 + 1,
            ),
        )

    assert error.value.code == "MEDIA_FILE_TOO_LARGE"
    assert repository.items == {}
    assert storage.upload_paths == []


def test_presign_schema_rejects_unsupported_type_and_checksum() -> None:
    with pytest.raises(ValidationError):
        build_request(content_type="image/gif")
    with pytest.raises(ValidationError):
        build_request(checksum_sha256="not-a-sha256")


async def test_complete_validates_object_and_is_idempotent() -> None:
    service, repository, storage = build_service()
    user_id = uuid4()
    presigned = await service.create_upload(user_id, build_request())

    first = await service.complete_upload(user_id, presigned.media_file_id)
    second = await service.complete_upload(user_id, presigned.media_file_id)

    assert first.status == MediaStatus.READY
    assert second.status == MediaStatus.READY
    assert repository.items[presigned.media_file_id].status == MediaStatus.READY
    assert storage.object_info.size_bytes == first.size_bytes


@pytest.mark.parametrize(
    ("object_info", "error_code"),
    [
        (StorageObjectInfo(size_bytes=999, content_type="image/jpeg"), "MEDIA_SIZE_MISMATCH"),
        (StorageObjectInfo(size_bytes=1024, content_type="image/png"), "MEDIA_TYPE_MISMATCH"),
    ],
)
async def test_complete_rejects_object_metadata_mismatch(
    object_info: StorageObjectInfo,
    error_code: str,
) -> None:
    service, _, storage = build_service()
    user_id = uuid4()
    presigned = await service.create_upload(user_id, build_request())
    storage.object_info = object_info

    with pytest.raises(AppError) as error:
        await service.complete_upload(user_id, presigned.media_file_id)

    assert error.value.code == error_code


@pytest.mark.parametrize(
    ("object_bytes", "error_code"),
    [
        (b"not-a-real-image" + (b"\x00" * 1008), "MEDIA_CONTENT_INVALID"),
        (b"\xff\xd8\xff" + (b"\x01" * 1021), "MEDIA_CHECKSUM_MISMATCH"),
    ],
)
async def test_complete_rejects_invalid_content_or_checksum(
    object_bytes: bytes,
    error_code: str,
) -> None:
    service, _, storage = build_service()
    user_id = uuid4()
    presigned = await service.create_upload(user_id, build_request())
    storage.object_bytes = object_bytes

    with pytest.raises(AppError) as error:
        await service.complete_upload(user_id, presigned.media_file_id)

    assert error.value.code == error_code


async def test_media_access_is_scoped_to_owner() -> None:
    service, _, _ = build_service()
    owner_id = uuid4()
    presigned = await service.create_upload(owner_id, build_request())

    with pytest.raises(AppError) as error:
        await service.complete_upload(uuid4(), presigned.media_file_id)

    assert error.value.code == "MEDIA_FILE_NOT_FOUND"
    assert error.value.status_code == 404


async def test_download_requires_ready_and_uses_configured_expiry() -> None:
    service, _, storage = build_service(download_url_expires_seconds=120)
    user_id = uuid4()
    presigned = await service.create_upload(user_id, build_request())

    with pytest.raises(AppError) as error:
        await service.create_download_url(user_id, presigned.media_file_id)
    assert error.value.code == "MEDIA_NOT_READY"

    await service.complete_upload(user_id, presigned.media_file_id)
    response = await service.create_download_url(user_id, presigned.media_file_id)

    assert response.download_url.startswith("https://storage.example/download/")
    assert storage.download_requests[0][1] == 120


async def test_delete_is_soft_delete_only() -> None:
    service, repository, storage = build_service()
    user_id = uuid4()
    presigned = await service.create_upload(user_id, build_request())

    await service.soft_delete(user_id, presigned.media_file_id)
    media_file = repository.items[presigned.media_file_id]

    assert media_file.status == MediaStatus.DELETED
    assert media_file.deleted_at is not None
    assert storage.deleted_paths == []


async def test_delete_route_enqueues_storage_cleanup_in_same_session() -> None:
    user_id = uuid4()
    media_file = MediaFile(
        id=uuid4(),
        user_id=user_id,
        purpose=MediaPurpose.DIAGNOSIS,
        status=MediaStatus.READY,
        bucket_name="leafie-media",
        object_path=f"{user_id}/diagnosis/{uuid4()}.jpg",
        content_type="image/jpeg",
        size_bytes=1024,
    )
    session = FakeSession(media_file)
    queue = FakeQueue()
    current_user = AuthenticatedUser(
        id=user_id,
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )
    token = set_request_id("req_media_delete_test")
    try:
        response = await delete_media(
            media_file.id,
            current_user,
            session,
            FakeStorageGateway(),
            queue,
        )
    finally:
        reset_request_id(token)

    assert response.status_code == 204
    assert media_file.status == MediaStatus.DELETED
    assert queue.sessions == [session]
    assert queue.jobs == [
        QueueJob(
            job_type=JobType.STORAGE_OBJECT_DELETE,
            resource_id=media_file.id,
            trace_id="req_media_delete_test",
        )
    ]


def test_media_routes_require_authentication() -> None:
    application = create_app()

    with TestClient(application) as client:
        response = client.post(
            "/api/v1/media/presign",
            json=build_request().model_dump(mode="json"),
        )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"
