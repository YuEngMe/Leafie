import hashlib
from datetime import UTC, datetime, timedelta
from typing import Protocol
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.integrations.storage import StorageGateway
from app.models.enums import MediaPurpose, MediaStatus
from app.models.media import MediaFile
from app.schemas.media import (
    MediaCompleteResponse,
    MediaDownloadResponse,
    MediaPresignRequest,
    MediaPresignResponse,
)

SIGNED_UPLOAD_EXPIRES_SECONDS = 2 * 60 * 60
MIME_EXTENSIONS = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}
PURPOSE_PATHS = {
    MediaPurpose.USER_PROFILE: "user-profile",
    MediaPurpose.PLANT_PROFILE: "plant-profile",
    MediaPurpose.SPECIES_IDENTIFICATION: "species-identification",
    MediaPurpose.DIARY: "diary",
    MediaPurpose.DIAGNOSIS: "diagnosis",
    MediaPurpose.CHAT: "chat",
}
PURPOSE_MAX_BYTES = {
    MediaPurpose.USER_PROFILE: 5 * 1024 * 1024,
    MediaPurpose.PLANT_PROFILE: 5 * 1024 * 1024,
    MediaPurpose.SPECIES_IDENTIFICATION: 10 * 1024 * 1024,
    MediaPurpose.DIARY: 10 * 1024 * 1024,
    MediaPurpose.DIAGNOSIS: 10 * 1024 * 1024,
    MediaPurpose.CHAT: 10 * 1024 * 1024,
}


class MediaRepository(Protocol):
    async def add(self, media_file: MediaFile) -> None: ...

    async def get_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None: ...


class SQLAlchemyMediaRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add(self, media_file: MediaFile) -> None:
        self._session.add(media_file)
        await self._session.flush()

    async def get_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile | None:
        statement = select(MediaFile).where(
            MediaFile.id == media_file_id,
            MediaFile.user_id == user_id,
            MediaFile.deleted_at.is_(None),
        )
        return await self._session.scalar(statement)


class MediaService:
    def __init__(
        self,
        repository: MediaRepository,
        storage: StorageGateway,
        *,
        download_url_expires_seconds: int = 300,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._download_url_expires_seconds = download_url_expires_seconds

    async def create_upload(
        self,
        user_id: UUID,
        request: MediaPresignRequest,
    ) -> MediaPresignResponse:
        maximum_size = PURPOSE_MAX_BYTES[request.purpose]
        if request.size_bytes > maximum_size:
            raise AppError(
                code="MEDIA_FILE_TOO_LARGE",
                message="업로드 가능한 파일 크기를 초과했습니다.",
                status_code=413,
                details={"max_size_bytes": maximum_size},
            )

        media_file_id = uuid4()
        extension = MIME_EXTENSIONS[request.content_type]
        object_path = f"{user_id}/{PURPOSE_PATHS[request.purpose]}/{media_file_id}.{extension}"
        issued_at = datetime.now(UTC)
        upload_url = await self._storage.create_signed_upload_url(object_path)
        media_file = MediaFile(
            id=media_file_id,
            user_id=user_id,
            purpose=request.purpose.value,
            status=MediaStatus.PENDING.value,
            bucket_name=self._storage.bucket_name,
            object_path=object_path,
            content_type=request.content_type,
            size_bytes=request.size_bytes,
            checksum_sha256=request.checksum_sha256.lower(),
        )
        await self._repository.add(media_file)

        return MediaPresignResponse(
            media_file_id=media_file_id,
            upload_url=upload_url,
            upload_headers={"Content-Type": request.content_type},
            expires_at=issued_at + timedelta(seconds=SIGNED_UPLOAD_EXPIRES_SECONDS),
        )

    async def complete_upload(
        self,
        user_id: UUID,
        media_file_id: UUID,
    ) -> MediaCompleteResponse:
        media_file = await self._get_owned(media_file_id, user_id)
        if media_file.status == MediaStatus.READY:
            return MediaCompleteResponse.model_validate(media_file)
        if media_file.status != MediaStatus.PENDING:
            raise AppError(
                code="MEDIA_INVALID_STATUS",
                message="업로드를 완료할 수 없는 파일 상태입니다.",
                status_code=409,
            )

        object_info = await self._storage.get_object_info(media_file.object_path)
        if object_info.size_bytes != media_file.size_bytes:
            raise AppError(
                code="MEDIA_SIZE_MISMATCH",
                message="업로드된 파일 크기가 요청 값과 일치하지 않습니다.",
                status_code=409,
            )
        if object_info.content_type != media_file.content_type:
            raise AppError(
                code="MEDIA_TYPE_MISMATCH",
                message="업로드된 파일 형식이 요청 값과 일치하지 않습니다.",
                status_code=409,
            )

        file_bytes = await self._storage.download_object(media_file.object_path)
        if len(file_bytes) != media_file.size_bytes:
            raise AppError(
                code="MEDIA_SIZE_MISMATCH",
                message="업로드된 파일 크기가 요청 값과 일치하지 않습니다.",
                status_code=409,
            )
        actual_content_type = detect_image_content_type(file_bytes)
        if actual_content_type != media_file.content_type:
            raise AppError(
                code="MEDIA_CONTENT_INVALID",
                message="실제 이미지 형식이 요청 값과 일치하지 않습니다.",
                status_code=409,
            )
        actual_checksum = hashlib.sha256(file_bytes).hexdigest()
        if actual_checksum != media_file.checksum_sha256:
            raise AppError(
                code="MEDIA_CHECKSUM_MISMATCH",
                message="업로드된 파일의 체크섬이 요청 값과 일치하지 않습니다.",
                status_code=409,
            )

        media_file.status = MediaStatus.READY.value
        return MediaCompleteResponse.model_validate(media_file)

    async def create_download_url(
        self,
        user_id: UUID,
        media_file_id: UUID,
    ) -> MediaDownloadResponse:
        media_file = await self._get_owned(media_file_id, user_id)
        if media_file.status != MediaStatus.READY:
            raise AppError(
                code="MEDIA_NOT_READY",
                message="아직 사용할 수 없는 파일입니다.",
                status_code=409,
            )

        issued_at = datetime.now(UTC)
        download_url = await self._storage.create_signed_download_url(
            media_file.object_path,
            expires_in=self._download_url_expires_seconds,
        )
        return MediaDownloadResponse(
            download_url=download_url,
            expires_at=issued_at + timedelta(seconds=self._download_url_expires_seconds),
        )

    async def soft_delete(self, user_id: UUID, media_file_id: UUID) -> None:
        media_file = await self._get_owned(media_file_id, user_id)
        media_file.status = MediaStatus.DELETED.value
        media_file.deleted_at = datetime.now(UTC)

    async def _get_owned(self, media_file_id: UUID, user_id: UUID) -> MediaFile:
        media_file = await self._repository.get_owned(media_file_id, user_id)
        if media_file is None:
            raise AppError(
                code="MEDIA_FILE_NOT_FOUND",
                message="파일을 찾을 수 없습니다.",
                status_code=404,
            )
        return media_file


def detect_image_content_type(file_bytes: bytes) -> str | None:
    if file_bytes.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if file_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(file_bytes) >= 12 and file_bytes.startswith(b"RIFF") and file_bytes[8:12] == b"WEBP":
        return "image/webp"
    return None
