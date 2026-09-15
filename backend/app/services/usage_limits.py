from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import AppError
from app.models.diagnosis import Diagnosis
from app.models.media import SpeciesIdentification
from app.models.plant import Plant


async def enforce_diagnosis_usage(session: AsyncSession, user_id: UUID) -> None:
    since = datetime.now(UTC) - timedelta(hours=24)
    count = await session.scalar(
        select(func.count(Diagnosis.id))
        .join(Plant, Plant.id == Diagnosis.plant_id)
        .where(Plant.user_id == user_id, Diagnosis.created_at >= since)
    )
    if (count or 0) > settings.diagnosis_requests_per_24_hours:
        _limited("DIAGNOSIS_DAILY_LIMIT_EXCEEDED", "오늘의 식물 진단 사용량을 모두 사용했습니다.")


async def enforce_identification_usage(session: AsyncSession, user_id: UUID) -> None:
    since = datetime.now(UTC) - timedelta(hours=24)
    count = await session.scalar(
        select(func.count(SpeciesIdentification.id)).where(
            SpeciesIdentification.user_id == user_id,
            SpeciesIdentification.created_at >= since,
        )
    )
    if (count or 0) > settings.species_identification_requests_per_24_hours:
        _limited(
            "SPECIES_IDENTIFICATION_DAILY_LIMIT_EXCEEDED",
            "오늘의 식물 사진 인식 사용량을 모두 사용했습니다.",
        )


def _limited(code: str, message: str, *, retry_after: int = 86400) -> None:
    raise AppError(
        code=code,
        message=message,
        status_code=429,
        headers={"Retry-After": str(retry_after)},
    )
