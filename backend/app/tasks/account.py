from typing import Protocol
from uuid import UUID

from sqlalchemy import select, update

from app.db.session import Database
from app.integrations.auth import AuthAdminGateway
from app.integrations.storage import StorageGateway
from app.models.enums import AccountDeletionStatus
from app.models.media import MediaFile
from app.models.user import UserProfile
from app.schemas.queue import QueueJob


class AccountCleanupRepository(Protocol):
    async def list_media_paths(self, user_id: UUID) -> list[str]: ...

    async def mark_deletion_failed(self, user_id: UUID) -> None: ...


class SQLAlchemyAccountCleanupRepository:
    def __init__(self, database: Database) -> None:
        self._database = database

    async def list_media_paths(self, user_id: UUID) -> list[str]:
        async with self._database.session_context() as session:
            result = await session.scalars(
                select(MediaFile.object_path).where(MediaFile.user_id == user_id)
            )
            return list(result)

    async def mark_deletion_failed(self, user_id: UUID) -> None:
        async with self._database.session_context() as session:
            await session.execute(
                update(UserProfile)
                .where(
                    UserProfile.user_id == user_id,
                    UserProfile.deleted_at.is_not(None),
                    UserProfile.deletion_status == AccountDeletionStatus.PENDING,
                )
                .values(deletion_status=AccountDeletionStatus.FAILED.value)
            )


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

    async def on_exhausted(self, job: QueueJob) -> None:
        # 일부 파일이 이미 삭제됐을 수 있으므로 계정을 복구하지 않고 관리자 재처리 대상으로 둡니다.
        await self._repository.mark_deletion_failed(job.resource_id)
