from uuid import uuid4

import pytest

from app.core.errors import AppError
from app.integrations.openai_chat import ChatCompletion, OpenAIChatPermanentError
from app.schemas.queue import JobType, QueueJob
from app.tasks.base import PermanentTaskError
from app.tasks.chat import ChatImageAnalysisHandler, ChatImageWork


class FakeRepository:
    def __init__(self) -> None:
        self.work = ChatImageWork(
            user_id=uuid4(),
            conversation_id=uuid4(),
            object_path="user/chat/image.jpg",
            content_type="image/jpeg",
            caption="잎 상태를 봐줘",
            instructions="식물 관리 도우미",
            messages=[],
        )
        self.completed: list[tuple] = []
        self.released: list = []
        self.failed: list = []

    async def start(self, _message_id):
        return self.work

    async def complete(self, message_id, completion):
        self.completed.append((message_id, completion))

    async def release_for_retry(self, message_id):
        self.released.append(message_id)

    async def fail(self, message_id):
        self.failed.append(message_id)


class FakeStorage:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error

    async def download_object(self, object_path: str) -> bytes:
        assert object_path == "user/chat/image.jpg"
        if self.error:
            raise self.error
        return b"image"


class FakeProvider:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error
        self.calls = 0

    async def reply_with_image(self, **kwargs):
        self.calls += 1
        assert kwargs["image"] == b"image"
        assert kwargs["caption"] == "잎 상태를 봐줘"
        if self.error:
            raise self.error
        return ChatCompletion(
            content="잎 끝이 말라 보여요.",
            response_id="resp_1",
            model_name="gpt-test",
            input_tokens=10,
            output_tokens=5,
        )


def make_job() -> QueueJob:
    return QueueJob(
        job_type=JobType.CHAT_IMAGE_ANALYSIS,
        resource_id=uuid4(),
        trace_id="req_chat_image",
    )


async def test_chat_image_handler_completes_reply() -> None:
    repository = FakeRepository()
    job = make_job()

    await ChatImageAnalysisHandler(repository, FakeStorage(), FakeProvider())(job)

    assert repository.completed[0][0] == job.resource_id
    assert repository.completed[0][1].content == "잎 끝이 말라 보여요."
    assert repository.released == []
    assert repository.failed == []


async def test_chat_image_handler_marks_permanent_provider_failure() -> None:
    repository = FakeRepository()
    provider = FakeProvider(OpenAIChatPermanentError("AI_PROVIDER_AUTH_FAILED"))
    job = make_job()

    with pytest.raises(PermanentTaskError):
        await ChatImageAnalysisHandler(repository, FakeStorage(), provider)(job)

    assert repository.failed == [job.resource_id]
    assert repository.released == []


async def test_chat_image_handler_releases_transient_failure() -> None:
    repository = FakeRepository()
    provider = FakeProvider(
        AppError(
            code="AI_PROVIDER_UNAVAILABLE",
            message="temporary",
            status_code=503,
        )
    )
    job = make_job()

    with pytest.raises(AppError):
        await ChatImageAnalysisHandler(repository, FakeStorage(), provider)(job)

    assert repository.released == [job.resource_id]
    assert repository.failed == []


async def test_chat_image_handler_ignores_already_processed_message() -> None:
    repository = FakeRepository()
    repository.work = None
    provider = FakeProvider()

    await ChatImageAnalysisHandler(repository, FakeStorage(), provider)(make_job())

    assert provider.calls == 0
    assert repository.completed == []
