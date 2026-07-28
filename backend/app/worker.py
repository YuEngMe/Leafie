import asyncio
import logging
import signal

from app.core.config import settings
from app.core.logging import configure_logging
from app.db.session import Database
from app.integrations.plantnet import PlantNetProvider
from app.integrations.queue import PgmqQueue
from app.integrations.storage import SupabaseStorageGateway
from app.schemas.queue import JobType
from app.services.worker import QueueWorker
from app.tasks.registry import TaskRegistry
from app.tasks.species import (
    SpeciesIdentificationHandler,
    SpeciesIdentificationRepository,
)
from app.tasks.storage import (
    SQLAlchemyMediaCleanupRepository,
    StorageObjectDeleteHandler,
)

configure_logging(settings.log_level)
logger = logging.getLogger(__name__)


async def run_worker() -> None:
    database = Database(settings)
    storage = SupabaseStorageGateway(settings)
    plantnet = PlantNetProvider(settings)
    queue = PgmqQueue(database, settings)
    registry = TaskRegistry()
    registry.register(
        JobType.STORAGE_OBJECT_DELETE,
        StorageObjectDeleteHandler(
            SQLAlchemyMediaCleanupRepository(database),
            storage,
        ),
    )
    registry.register(
        JobType.SPECIES_IDENTIFICATION_RUN,
        SpeciesIdentificationHandler(
            SpeciesIdentificationRepository(database),
            storage,
            plantnet,
        ),
    )
    worker = QueueWorker(
        queue,
        registry,
        poll_interval_seconds=settings.worker_poll_interval_seconds,
        visibility_timeout_seconds=settings.worker_visibility_timeout_seconds,
        max_attempts=settings.worker_max_attempts,
        retry_base_seconds=settings.worker_retry_base_seconds,
        retry_max_seconds=settings.worker_retry_max_seconds,
        batch_size=settings.worker_batch_size,
    )
    stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()
    for signal_name in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(signal_name, stop_event.set)

    try:
        await worker.run(stop_event)
    finally:
        await plantnet.close()
        await storage.close()
        await database.close()


def main() -> None:
    asyncio.run(run_worker())


if __name__ == "__main__":
    main()
