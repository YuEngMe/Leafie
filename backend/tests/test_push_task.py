from types import SimpleNamespace
from uuid import uuid4

import pytest
from firebase_admin import exceptions, messaging
from google.auth.exceptions import DefaultCredentialsError

from app.integrations.push import FirebasePushGateway, PushPermanentError, PushResult
from app.schemas.queue import JobType, QueueJob
from app.tasks.base import PermanentTaskError
from app.tasks.push import PushNotificationHandler, PushWork


class FakeRepository:
    def __init__(self, work: PushWork | None) -> None:
        self.work = work
        self.revoked: list[str] = []

    async def load(self, _notification_id):
        return self.work

    async def revoke_tokens(self, tokens):
        self.revoked.extend(tokens)


class FakeGateway:
    def __init__(
        self,
        result: PushResult | None = None,
        error: Exception | None = None,
    ) -> None:
        self.result = result or PushResult([])
        self.error = error
        self.calls: list[dict] = []

    async def send(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise self.error
        return self.result


def make_job(notification_id=None) -> QueueJob:
    return QueueJob(
        job_type=JobType.PUSH_NOTIFICATION_SEND,
        resource_id=notification_id or uuid4(),
        trace_id="push-test",
    )


def make_work(installation_ids=None) -> PushWork:
    return PushWork(
        notification_id=uuid4(),
        plant_id=uuid4(),
        title="진단 완료",
        body="결과를 확인해 주세요.",
        installation_ids=(
            installation_ids if installation_ids is not None else ["installation-1"]
        ),
    )


async def test_push_handler_sends_notification_and_revokes_invalid_tokens() -> None:
    work = make_work(["valid", "invalid"])
    repository = FakeRepository(work)
    gateway = FakeGateway(PushResult(invalid_tokens=["invalid"]))

    await PushNotificationHandler(repository, gateway)(make_job(work.notification_id))

    assert gateway.calls[0]["installation_ids"] == ["valid", "invalid"]
    assert gateway.calls[0]["data"]["plant_id"] == str(work.plant_id)
    assert repository.revoked == ["invalid"]


async def test_push_handler_skips_missing_notification_or_disabled_push() -> None:
    gateway = FakeGateway()

    await PushNotificationHandler(FakeRepository(None), gateway)(make_job())
    await PushNotificationHandler(FakeRepository(make_work([])), gateway)(make_job())

    assert gateway.calls == []


async def test_push_handler_retries_transient_failure_after_revoking_invalid_tokens() -> None:
    repository = FakeRepository(make_work())
    gateway = FakeGateway(PushResult(["invalid"], retryable_failures=1))

    with pytest.raises(RuntimeError, match="FCM retryable failures"):
        await PushNotificationHandler(repository, gateway)(make_job())

    assert repository.revoked == ["invalid"]


async def test_push_handler_archives_permanent_configuration_failure() -> None:
    gateway = FakeGateway(error=PushPermanentError("FCM_NOT_CONFIGURED"))

    with pytest.raises(PermanentTaskError) as error:
        await PushNotificationHandler(FakeRepository(make_work()), gateway)(make_job())

    assert error.value.failure_code == "FCM_NOT_CONFIGURED"


async def test_firebase_gateway_marks_missing_default_credentials_permanent(monkeypatch) -> None:
    gateway = object.__new__(FirebasePushGateway)
    gateway._app = object()

    async def fail_send_each(_messages, *, app):
        assert app is gateway._app
        raise DefaultCredentialsError("missing")

    monkeypatch.setattr(messaging, "send_each_async", fail_send_each)

    with pytest.raises(PushPermanentError, match="DefaultCredentialsError"):
        await gateway.send(
            notification_id=str(uuid4()),
            title="제목",
            body="내용",
            data={},
            installation_ids=["fid"],
        )


async def test_firebase_gateway_classifies_token_and_transient_errors(monkeypatch) -> None:
    gateway = object.__new__(FirebasePushGateway)
    gateway._app = object()

    async def fake_send_each(messages, *, app):
        assert app is gateway._app
        assert len(messages) == 3
        return SimpleNamespace(
            responses=[
                SimpleNamespace(success=True, exception=None),
                SimpleNamespace(
                    success=False,
                    exception=messaging.UnregisteredError("expired"),
                ),
                SimpleNamespace(
                    success=False,
                    exception=exceptions.UnavailableError("temporary"),
                ),
            ]
        )

    monkeypatch.setattr(messaging, "send_each_async", fake_send_each)

    result = await gateway.send(
        notification_id=str(uuid4()),
        title="제목",
        body="내용",
        data={"kind": "diagnosis"},
        installation_ids=["valid", "expired", "retry"],
    )

    assert result.invalid_tokens == ["expired"]
    assert result.retryable_failures == 1
    assert result.permanent_failures == 0
