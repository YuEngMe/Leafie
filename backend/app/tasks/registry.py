from app.schemas.queue import JobType
from app.tasks.base import TaskHandler


class TaskRegistry:
    def __init__(self) -> None:
        self._handlers: dict[JobType, TaskHandler] = {}

    def register(self, job_type: JobType, handler: TaskHandler) -> None:
        if job_type in self._handlers:
            raise ValueError(f"Handler already registered: {job_type}")
        self._handlers[job_type] = handler

    def get(self, job_type: JobType) -> TaskHandler | None:
        return self._handlers.get(job_type)
