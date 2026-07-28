from typing import Protocol
from uuid import UUID

from sqlalchemy import select

from app.db.session import Database
from app.integrations.storage import StorageGateway
from app.models.enums import MediaStatus
from app.models.media import MediaFile
from app.schemas.queue import QueueJob
from app.tasks.base import PermanentTaskError


class MediaCleanupRepository(Protocol):
    async def get(self, media_file_id: UUID) -> MediaFile | None: ...


class SQLAlchemyMediaCleanupRepository:
    def __init__(self, database: Database) -> None:
        self._database = database

    async def get(self, media_file_id: UUID) -> MediaFile | None:
        async with self._database.session_context() as session:
            return await session.scalar(select(MediaFile).where(MediaFile.id == media_file_id))


class StorageObjectDeleteHandler:
    def __init__(
        self,
        repository: MediaCleanupRepository,
        storage: StorageGateway,
    ) -> None:
        self._repository = repository
        self._storage = storage

    async def __call__(self, job: QueueJob) -> None:
        media_file = await self._repository.get(job.resource_id)
        if media_file is None:
            return
        if media_file.status != MediaStatus.DELETED:
            raise PermanentTaskError(
                "MEDIA_NOT_DELETED",
                "Soft delete되지 않은 미디어는 Storage에서 삭제할 수 없습니다.",
            )
        await self._storage.delete_object(media_file.object_path)
