from uuid import uuid4

import pytest

from app.core.config import settings
from app.core.errors import AppError
from app.services.usage_limits import (
    enforce_chat_usage,
    enforce_diagnosis_usage,
    enforce_identification_usage,
)


class FakeSession:
    def __init__(self, *counts: int) -> None:
        self._counts = iter(counts)

    async def scalar(self, _statement):
        return next(self._counts)


async def test_chat_usage_rejects_burst_requests() -> None:
    session = FakeSession(settings.ai_chat_requests_per_minute + 1, 1)

    with pytest.raises(AppError) as error:
        await enforce_chat_usage(session, uuid4())  # type: ignore[arg-type]

    assert error.value.code == "AI_CHAT_RATE_LIMITED"
    assert error.value.status_code == 429
    assert error.value.headers == {"Retry-After": "60"}


async def test_diagnosis_usage_rejects_daily_overage() -> None:
    session = FakeSession(settings.diagnosis_requests_per_24_hours + 1)

    with pytest.raises(AppError) as error:
        await enforce_diagnosis_usage(session, uuid4())  # type: ignore[arg-type]

    assert error.value.code == "DIAGNOSIS_DAILY_LIMIT_EXCEEDED"


async def test_identification_usage_rejects_daily_overage() -> None:
    session = FakeSession(settings.species_identification_requests_per_24_hours + 1)

    with pytest.raises(AppError) as error:
        await enforce_identification_usage(session, uuid4())  # type: ignore[arg-type]

    assert error.value.code == "SPECIES_IDENTIFICATION_DAILY_LIMIT_EXCEEDED"
