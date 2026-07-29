from dataclasses import dataclass
from typing import Protocol

import httpx
from storage3 import AsyncStorageClient
from storage3.exceptions import StorageApiError, StorageException

from app.core.config import Settings
from app.core.errors import AppError


@dataclass(frozen=True, slots=True)
class StorageObjectInfo:
    size_bytes: int
    content_type: str


class StorageGateway(Protocol):
    @property
    def bucket_name(self) -> str: ...

    async def create_signed_upload_url(self, object_path: str) -> str: ...

    async def get_object_info(self, object_path: str) -> StorageObjectInfo: ...

    async def download_object(self, object_path: str) -> bytes: ...

    async def create_signed_download_url(
        self,
        object_path: str,
        *,
        expires_in: int,
    ) -> str: ...

    async def delete_object(self, object_path: str) -> None: ...


class SupabaseStorageGateway:
    def __init__(self, settings: Settings) -> None:
        self._url = settings.supabase_url
        self._secret_key = settings.supabase_secret_key
        self._bucket_name = settings.supabase_storage_bucket
        self._client: AsyncStorageClient | None = None

    @property
    def bucket_name(self) -> str:
        return self._bucket_name

    async def create_signed_upload_url(self, object_path: str) -> str:
        try:
            response = await self._bucket().create_signed_upload_url(object_path)
            return response["signed_url"]
        except (httpx.HTTPError, StorageException, KeyError) as exc:
            raise self._unavailable_error() from exc

    async def get_object_info(self, object_path: str) -> StorageObjectInfo:
        try:
            response = await self._bucket().info(object_path)
        except StorageApiError as exc:
            if str(exc.status) in {"400", "404"}:
                raise AppError(
                    code="MEDIA_UPLOAD_NOT_FOUND",
                    message="업로드된 파일을 찾을 수 없습니다.",
                    status_code=409,
                ) from exc
            raise self._unavailable_error() from exc
        except (httpx.HTTPError, StorageException) as exc:
            raise self._unavailable_error() from exc

        metadata = response.get("metadata") or {}
        size = metadata.get("size", response.get("size"))
        content_type = (
            metadata.get("mimetype")
            or metadata.get("contentType")
            or response.get("mimetype")
            or response.get("content_type")
        )
        try:
            parsed_size = int(size)
        except (TypeError, ValueError) as exc:
            raise self._unavailable_error() from exc
        if not isinstance(content_type, str):
            raise self._unavailable_error() from ValueError("Missing object MIME type")

        return StorageObjectInfo(size_bytes=parsed_size, content_type=content_type.lower())

    async def download_object(self, object_path: str) -> bytes:
        try:
            return await self._bucket().download(object_path)
        except StorageApiError as exc:
            if str(exc.status) == "404":
                raise AppError(
                    code="MEDIA_UPLOAD_NOT_FOUND",
                    message="업로드된 파일을 찾을 수 없습니다.",
                    status_code=409,
                ) from exc
            raise self._unavailable_error() from exc
        except (httpx.HTTPError, StorageException) as exc:
            raise self._unavailable_error() from exc

    async def create_signed_download_url(
        self,
        object_path: str,
        *,
        expires_in: int,
    ) -> str:
        try:
            response = await self._bucket().create_signed_url(object_path, expires_in)
            signed_url = response.get("signed_url") or response.get("signedURL")
            if not signed_url:
                raise ValueError("Missing signed download URL")
            return signed_url
        except StorageApiError as exc:
            if str(exc.status) == "404":
                raise AppError(
                    code="MEDIA_FILE_NOT_FOUND",
                    message="파일을 찾을 수 없습니다.",
                    status_code=404,
                ) from exc
            raise self._unavailable_error() from exc
        except (httpx.HTTPError, StorageException, ValueError) as exc:
            raise self._unavailable_error() from exc

    async def delete_object(self, object_path: str) -> None:
        try:
            await self._bucket().remove([object_path])
        except StorageApiError as exc:
            if str(exc.status) == "404":
                return
            raise self._unavailable_error() from exc
        except (httpx.HTTPError, StorageException) as exc:
            raise self._unavailable_error() from exc

    async def close(self) -> None:
        if self._client is not None:
            await self._client.session.aclose()
            self._client = None

    def _bucket(self):
        if not self._url or not self._secret_key or not self._bucket_name:
            raise AppError(
                code="STORAGE_NOT_CONFIGURED",
                message="파일 저장소 설정이 완료되지 않았습니다.",
                status_code=503,
            )
        if self._client is None:
            self._client = AsyncStorageClient(
                f"{self._url.rstrip('/')}/storage/v1/",
                headers={
                    "apikey": self._secret_key,
                    "Authorization": f"Bearer {self._secret_key}",
                },
            )
        return self._client.from_(self._bucket_name)

    @staticmethod
    def _unavailable_error() -> AppError:
        return AppError(
            code="STORAGE_UNAVAILABLE",
            message="파일 저장소를 사용할 수 없습니다.",
            status_code=503,
        )
