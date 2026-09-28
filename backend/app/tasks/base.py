from typing import Protocol

from app.schemas.queue import QueueJob


class PermanentTaskError(Exception):
    def __init__(self, failure_code: str, message: str) -> None:
        super().__init__(message)
        self.failure_code = failure_code


class TaskDeferred(Exception):
    """A live execution owns the resource; keep its recovery message in the queue."""

    def __init__(self, delay_seconds: int) -> None:
        super().__init__("Task lease is still active")
        self.delay_seconds = max(1, delay_seconds)


class TaskHandler(Protocol):
    async def __call__(self, job: QueueJob) -> None: ...
