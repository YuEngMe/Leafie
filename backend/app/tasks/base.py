from typing import Protocol

from app.schemas.queue import QueueJob


class PermanentTaskError(Exception):
    def __init__(self, failure_code: str, message: str) -> None:
        super().__init__(message)
        self.failure_code = failure_code


class TaskHandler(Protocol):
    async def __call__(self, job: QueueJob) -> None: ...
