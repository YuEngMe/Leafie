import asyncio
import json
from dataclasses import dataclass
from typing import Protocol

import firebase_admin
from firebase_admin import credentials, exceptions, messaging
from google.auth.exceptions import DefaultCredentialsError

from app.core.config import Settings


class PushPermanentError(Exception):
    pass


@dataclass(frozen=True, slots=True)
class PushResult:
    invalid_tokens: list[str]
    retryable_failures: int = 0
    permanent_failures: int = 0


class PushGateway(Protocol):
    async def send(
        self,
        *,
        notification_id: str,
        title: str,
        body: str,
        data: dict[str, str],
        installation_ids: list[str],
    ) -> PushResult: ...


class FirebasePushGateway:
    def __init__(self, settings: Settings) -> None:
        credential = credentials.ApplicationDefault()
        if settings.fcm_credentials_json:
            try:
                credential_data = json.loads(settings.fcm_credentials_json)
            except json.JSONDecodeError as exc:
                raise ValueError("FCM_CREDENTIALS_JSON 형식이 올바르지 않습니다.") from exc
            credential = credentials.Certificate(credential_data)
        self._app = firebase_admin.initialize_app(
            credential,
            {"projectId": settings.firebase_project_id},
            name="leafie-push",
        )

    async def send(
        self,
        *,
        notification_id: str,
        title: str,
        body: str,
        data: dict[str, str],
        installation_ids: list[str],
    ) -> PushResult:
        invalid_tokens: list[str] = []
        retryable_failures = 0
        permanent_failures = 0
        for start in range(0, len(installation_ids), 500):
            chunk = installation_ids[start : start + 500]
            messages = [
                messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data=data,
                    fid=token,
                    apns=messaging.APNSConfig(
                        headers={"apns-collapse-id": notification_id},
                        payload=messaging.APNSPayload(aps=messaging.Aps(sound="default")),
                    ),
                    android=messaging.AndroidConfig(collapse_key=notification_id),
                )
                for token in chunk
            ]
            try:
                response = await asyncio.to_thread(
                    messaging.send_each,
                    messages,
                    app=self._app,
                )
            except (
                DefaultCredentialsError,
                messaging.ThirdPartyAuthError,
                exceptions.FailedPreconditionError,
                exceptions.InvalidArgumentError,
                exceptions.NotFoundError,
                exceptions.PermissionDeniedError,
                exceptions.UnauthenticatedError,
            ) as exc:
                raise PushPermanentError(type(exc).__name__) from exc
            except (
                messaging.QuotaExceededError,
                exceptions.AbortedError,
                exceptions.DeadlineExceededError,
                exceptions.InternalError,
                exceptions.ResourceExhaustedError,
                exceptions.UnavailableError,
                exceptions.UnknownError,
            ):
                retryable_failures += len(chunk)
                continue

            for token, item in zip(chunk, response.responses, strict=True):
                if item.success:
                    continue
                if isinstance(
                    item.exception,
                    (
                        exceptions.InvalidArgumentError,
                        messaging.SenderIdMismatchError,
                        messaging.UnregisteredError,
                    ),
                ):
                    invalid_tokens.append(token)
                elif isinstance(
                    item.exception,
                    (
                        messaging.QuotaExceededError,
                        exceptions.AbortedError,
                        exceptions.DeadlineExceededError,
                        exceptions.InternalError,
                        exceptions.ResourceExhaustedError,
                        exceptions.UnavailableError,
                        exceptions.UnknownError,
                    ),
                ):
                    retryable_failures += 1
                else:
                    permanent_failures += 1

        return PushResult(
            invalid_tokens=invalid_tokens,
            retryable_failures=retryable_failures,
            permanent_failures=permanent_failures,
        )
