from typing import Protocol
from uuid import UUID

from sqlalchemy import select

from app.db.session import Database
from app.integrations.auth import AuthAdminGateway
from app.integrations.storage import StorageGateway
from app.models.media import MediaFile
from app.schemas.queue import QueueJob


class AccountCleanupRepository(Protocol):
    async def list_media_paths(self, user_id: UUID) -> list[str]: ...


class SQLAlchemyAccountCleanupRepository:
    def __init__(self, database: Database) -> None:
        self._database = database

    async def list_media_paths(self, user_id: UUID) -> list[str]:
        async with self._database.session_context() as session:
            result = await session.scalars(
                select(MediaFile.object_path).where(MediaFile.user_id == user_id)
            )
            return list(result)


class AccountDeleteHandler:
    def __init__(
        self,
        repository: AccountCleanupRepository,
        storage: StorageGateway,
        auth_admin: AuthAdminGateway,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._auth_admin = auth_admin

    async def __call__(self, job: QueueJob) -> None:
        for object_path in await self._repository.list_media_paths(job.resource_id):
            await self._storage.delete_object(object_path)
        # auth.users 삭제가 public 업무 데이터의 ON DELETE CASCADE를 시작합니다.
        await self._auth_admin.delete_user(job.resource_id)
