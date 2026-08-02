from typing import Protocol
from uuid import UUID

from sqlalchemy import delete, select

from app.db.session import Database
from app.integrations.storage import StorageGateway
from app.models.media import MediaFile, SpeciesIdentification
from app.models.plant import Plant
from app.schemas.queue import QueueJob
from app.services.plant_management import plant_media_ids_query
from app.tasks.base import PermanentTaskError


class PlantCleanupRepository(Protocol):
    async def list_media_paths(self, plant_id: UUID) -> list[str]: ...

    async def hard_delete(self, plant_id: UUID) -> None: ...


class SQLAlchemyPlantCleanupRepository:
    def __init__(self, database: Database) -> None:
        self._database = database

    async def list_media_paths(self, plant_id: UUID) -> list[str]:
        async with self._database.session_context() as session:
            result = await session.scalars(
                select(MediaFile.object_path)
                .where(MediaFile.id.in_(plant_media_ids_query(plant_id)))
                .order_by(MediaFile.object_path)
            )
            return list(result)

    async def hard_delete(self, plant_id: UUID) -> None:
        async with self._database.session_context() as session:
            plant = await session.scalar(
                select(Plant).where(Plant.id == plant_id).with_for_update()
            )
            if plant is None:
                return
            if plant.deleted_at is None:
                raise PermanentTaskError(
                    "PLANT_NOT_DELETED",
                    "Soft delete되지 않은 식물은 정리할 수 없습니다.",
                )
            identification_id = plant.species_identification_id
            await session.execute(delete(Plant).where(Plant.id == plant_id))
            if identification_id is not None:
                await session.execute(
                    delete(SpeciesIdentification).where(
                        SpeciesIdentification.id == identification_id
                    )
                )


class PlantDeleteHandler:
    def __init__(
        self,
        repository: PlantCleanupRepository,
        storage: StorageGateway,
    ) -> None:
        self._repository = repository
        self._storage = storage

    async def __call__(self, job: QueueJob) -> None:
        for object_path in await self._repository.list_media_paths(job.resource_id):
            await self._storage.delete_object(object_path)
        await self._repository.hard_delete(job.resource_id)
