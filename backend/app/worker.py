import asyncio
import logging
import signal

from app.core.config import settings
from app.core.logging import configure_logging
from app.db.session import Database
from app.integrations.auth import SupabaseAuthAdminGateway
from app.integrations.diagnosis import LocalDiagnosisImageQualityChecker
from app.integrations.kindwise import KindwiseDiagnosisProvider
from app.integrations.openai_chat import OpenAIChatProvider
from app.integrations.plantnet import PlantNetProvider
from app.integrations.push import FirebasePushGateway
from app.integrations.queue import PgmqQueue
from app.integrations.storage import SupabaseStorageGateway
from app.schemas.queue import JobType
from app.services.worker import QueueWorker
from app.tasks.account import AccountDeleteHandler, SQLAlchemyAccountCleanupRepository
from app.tasks.care_notification import (
    CareNotificationCollectHandler,
    SQLAlchemyCareNotificationRepository,
)
from app.tasks.chat import ChatImageAnalysisHandler, SQLAlchemyChatImageRepository
from app.tasks.diagnosis import (
    DiagnosisHandler,
    SQLAlchemyDiagnosisRepository,
    build_recommended_care,
)
from app.tasks.plant import PlantDeleteHandler, SQLAlchemyPlantCleanupRepository
from app.tasks.push import PushNotificationHandler, SQLAlchemyPushRepository
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
    auth_admin = SupabaseAuthAdminGateway(settings)
    plantnet = PlantNetProvider(settings)
    openai_chat = OpenAIChatProvider(settings)
    kindwise = KindwiseDiagnosisProvider(settings)
    push = FirebasePushGateway(settings)
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
        JobType.ACCOUNT_DELETE,
        AccountDeleteHandler(
            SQLAlchemyAccountCleanupRepository(database),
            storage,
            auth_admin,
        ),
    )
    registry.register(
        JobType.PLANT_DELETE,
        PlantDeleteHandler(
            SQLAlchemyPlantCleanupRepository(database),
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
    registry.register(
        JobType.CHAT_IMAGE_ANALYSIS,
        ChatImageAnalysisHandler(
            SQLAlchemyChatImageRepository(
                database,
                context_limit=settings.ai_chat_context_message_limit,
            ),
            storage,
            openai_chat,
        ),
    )
    registry.register(
        JobType.DIAGNOSIS_RUN,
        DiagnosisHandler(
            SQLAlchemyDiagnosisRepository(database, queue),
            storage,
            LocalDiagnosisImageQualityChecker(),
            kindwise,
            build_recommended_care,
            external_call_timeout_seconds=settings.kindwise_timeout_seconds,
        ),
    )
    registry.register(
        JobType.CARE_NOTIFICATION_COLLECT,
        CareNotificationCollectHandler(
            SQLAlchemyCareNotificationRepository(database, queue),
        ),
    )
    registry.register(
        JobType.PUSH_NOTIFICATION_SEND,
        PushNotificationHandler(SQLAlchemyPushRepository(database), push),
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
        await auth_admin.close()
        await plantnet.close()
        await openai_chat.close()
        await kindwise.close()
        await storage.close()
        await database.close()


def main() -> None:
    asyncio.run(run_worker())


if __name__ == "__main__":
    main()
