from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol

from sqlalchemy import bindparam, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.db.session import Database
from app.schemas.queue import QueueJob

SEND_QUERY = text(
    """
    SELECT *
    FROM pgmq.send(
        CAST(:queue_name AS text),
        :message,
        CAST(:delay AS integer)
    )
    """
).bindparams(bindparam("message", type_=JSONB))
READ_QUERY = text(
    """
    SELECT msg_id, read_ct, enqueued_at, vt, message
    FROM pgmq.read(
        CAST(:queue_name AS text),
        CAST(:visibility_timeout AS integer),
        CAST(:quantity AS integer),
        CAST(NULL AS jsonb)
    )
    """
)
ARCHIVE_QUERY = text(
    """
    SELECT pgmq.archive(
        CAST(:queue_name AS text),
        CAST(:message_id AS bigint)
    )
    """
)
SET_VISIBILITY_QUERY = text(
    """
    SELECT msg_id
    FROM pgmq.set_vt(
        CAST(:queue_name AS text),
        CAST(:message_id AS bigint),
        CAST(:visibility_timeout AS integer)
    )
    """
)


@dataclass(frozen=True, slots=True)
class ReceivedQueueMessage:
    message_id: int
    read_count: int
    enqueued_at: datetime
    visible_at: datetime
    message: Any


class JobQueue(Protocol):
    async def enqueue(
        self,
        job: QueueJob,
        *,
        delay_seconds: int = 0,
        session: AsyncSession | None = None,
    ) -> int: ...

    async def read(
        self,
        *,
        visibility_timeout_seconds: int,
        quantity: int,
    ) -> list[ReceivedQueueMessage]: ...

    async def archive(self, message_id: int) -> bool: ...

    async def set_visibility_timeout(
        self,
        message_id: int,
        *,
        visibility_timeout_seconds: int,
    ) -> bool: ...


class PgmqQueue:
    def __init__(self, database: Database, settings: Settings) -> None:
        self._database = database
        self._queue_name = settings.supabase_queue_name

    async def enqueue(
        self,
        job: QueueJob,
        *,
        delay_seconds: int = 0,
        session: AsyncSession | None = None,
    ) -> int:
        parameters = {
            "queue_name": self._queue_name,
            "message": job.model_dump(mode="json"),
            "delay": delay_seconds,
        }
        if session is not None:
            result = await session.execute(SEND_QUERY, parameters)
            return int(result.scalar_one())

        async with self._database.session_context() as owned_session:
            result = await owned_session.execute(SEND_QUERY, parameters)
            return int(result.scalar_one())

    async def read(
        self,
        *,
        visibility_timeout_seconds: int,
        quantity: int,
    ) -> list[ReceivedQueueMessage]:
        async with self._database.session_context() as session:
            result = await session.execute(
                READ_QUERY,
                {
                    "queue_name": self._queue_name,
                    "visibility_timeout": visibility_timeout_seconds,
                    "quantity": quantity,
                },
            )
            return [
                ReceivedQueueMessage(
                    message_id=row.msg_id,
                    read_count=row.read_ct,
                    enqueued_at=row.enqueued_at,
                    visible_at=row.vt,
                    message=row.message,
                )
                for row in result
            ]

    async def archive(self, message_id: int) -> bool:
        async with self._database.session_context() as session:
            result = await session.execute(
                ARCHIVE_QUERY,
                {"queue_name": self._queue_name, "message_id": message_id},
            )
            return bool(result.scalar_one())

    async def set_visibility_timeout(
        self,
        message_id: int,
        *,
        visibility_timeout_seconds: int,
    ) -> bool:
        async with self._database.session_context() as session:
            result = await session.execute(
                SET_VISIBILITY_QUERY,
                {
                    "queue_name": self._queue_name,
                    "message_id": message_id,
                    "visibility_timeout": visibility_timeout_seconds,
                },
            )
            return result.first() is not None
