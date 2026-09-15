from uuid import uuid4

import pytest

from app.core.config import settings
from app.core.errors import AppError
from app.services.usage_limits import enforce_diagnosis_usage, enforce_identification_usage


class FakeSession:
    def __init__(self, *counts: int) -> None:
        self._counts = iter(counts)

    async def scalar(self, _statement):
        return next(self._counts)


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
