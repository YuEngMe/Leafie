from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import AppError
from app.models.chat import AIConversation, AIMessage
from app.models.diagnosis import Diagnosis
from app.models.enums import ChatRole
from app.models.media import SpeciesIdentification
from app.models.plant import Plant


async def enforce_chat_usage(session: AsyncSession, user_id: UUID) -> None:
    now = datetime.now(UTC)
    recent, daily = await _chat_counts(session, user_id, now)
    if recent > settings.ai_chat_requests_per_minute:
        _limited("AI_CHAT_RATE_LIMITED", "잠시 후 다시 질문해 주세요.", retry_after=60)
    if daily > settings.ai_chat_requests_per_24_hours:
        _limited("AI_CHAT_DAILY_LIMIT_EXCEEDED", "오늘의 AI 채팅 사용량을 모두 사용했습니다.")


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


async def _chat_counts(
    session: AsyncSession, user_id: UUID, now: datetime
) -> tuple[int, int]:
    base = (
        select(func.count(AIMessage.id))
        .join(AIConversation, AIConversation.id == AIMessage.conversation_id)
        .join(Plant, Plant.id == AIConversation.plant_id)
        .where(
            Plant.user_id == user_id,
            AIMessage.role == ChatRole.USER.value,
        )
    )
    recent = await session.scalar(base.where(AIMessage.created_at >= now - timedelta(minutes=1)))
    daily = await session.scalar(base.where(AIMessage.created_at >= now - timedelta(hours=24)))
    return recent or 0, daily or 0


def _limited(code: str, message: str, *, retry_after: int = 86400) -> None:
    raise AppError(
        code=code,
        message=message,
        status_code=429,
        headers={"Retry-After": str(retry_after)},
    )
