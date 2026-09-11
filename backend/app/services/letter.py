import base64
import binascii
import json
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from sqlalchemy import delete, func, select, tuple_
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.integrations.queue import JobQueue
from app.models.letter import Letter
from app.models.notification import Notification
from app.models.plant import Plant, PlantDiary
from app.models.user import UserProfile
from app.schemas.letter import LetterDetail, LetterListItem, LetterListResponse
from app.schemas.queue import JobType, QueueJob


async def lock_active_plant(session: AsyncSession, user_id: UUID, plant_id: UUID) -> Plant | None:
    # Match deletion's lock order: account -> plant -> diary/letter.
    profile = await session.scalar(
        select(UserProfile)
        .where(
            UserProfile.user_id == user_id,
            UserProfile.deleted_at.is_(None),
            UserProfile.deletion_status.is_(None),
        )
        .with_for_update()
    )
    if profile is None:
        return None
    return await session.scalar(
        select(Plant)
        .where(
            Plant.id == plant_id,
            Plant.user_id == user_id,
            Plant.deleted_at.is_(None),
        )
        .with_for_update()
    )


async def reserve_letter(
    session: AsyncSession,
    queue: JobQueue,
    *,
    user_id: UUID,
    diary_id: UUID,
    created: bool,
) -> Letter | None:
    """Call only for a newly inserted diary, inside its transaction, after flush.

    No commit here: diary, reservation and pgmq send must succeed or roll back together.
    The caller must acquire account/plant locks before inserting the diary.
    """
    if not created:
        return None
    diary = await session.get(PlantDiary, diary_id)
    if diary is None or await lock_active_plant(session, user_id, diary.plant_id) is None:
        raise AppError(
            code="DIARY_NOT_FOUND", message="다이어리를 찾을 수 없습니다.", status_code=404
        )
    now = datetime.now(UTC)
    letter_id = await session.scalar(
        insert(Letter)
        .values(
            id=uuid4(),
            plant_id=diary.plant_id,
            diary_id=diary.id,
            diary_date=diary.diary_date,
            scheduled_at=now + timedelta(seconds=300 + secrets.randbelow(601)),
        )
        .on_conflict_do_nothing(index_elements=[Letter.diary_id])
        .returning(Letter.id)
    )
    if letter_id is not None:
        await queue.enqueue(
            QueueJob(
                job_type=JobType.LETTER_GENERATION_RUN,
                resource_id=letter_id,
                trace_id=f"letter:{letter_id}",
            ),
            session=session,
        )
    return await session.scalar(select(Letter).where(Letter.diary_id == diary_id))


def visible_letters(user_id: UUID, *, include_deleted: bool = False):
    statement = (
        select(Letter, Plant.nickname)
        .join(Plant, Plant.id == Letter.plant_id)
        .join(UserProfile, UserProfile.user_id == Plant.user_id)
        .where(
            Plant.user_id == user_id,
            Plant.deleted_at.is_(None),
            UserProfile.deleted_at.is_(None),
            UserProfile.deletion_status.is_(None),
            Letter.status == "COMPLETED",
            Letter.published_at.is_not(None),
            Letter.published_at <= func.now(),
        )
    )
    return statement if include_deleted else statement.where(Letter.deleted_at.is_(None))


def encode_letter_cursor(letter: Letter) -> str:
    value = json.dumps([letter.published_at.isoformat(), str(letter.id)])
    return base64.urlsafe_b64encode(value.encode()).decode().rstrip("=")


def decode_letter_cursor(cursor: str) -> tuple[datetime, UUID]:
    try:
        value = json.loads(
            base64.b64decode(cursor + "=" * (-len(cursor) % 4), altchars=b"-_", validate=True)
        )
        if (
            not isinstance(value, list)
            or len(value) != 2
            or not all(isinstance(item, str) for item in value)
        ):
            raise ValueError
        timestamp = datetime.fromisoformat(value[0])
        if timestamp.tzinfo is None:
            raise ValueError
        return timestamp, UUID(value[1])
    except (ValueError, TypeError, binascii.Error, UnicodeDecodeError) as from_exc:
        raise AppError(
            code="INVALID_CURSOR", message="페이지 정보를 확인해 주세요.", status_code=422
        ) from from_exc


def letter_item(letter: Letter, nickname: str) -> LetterListItem:
    return LetterListItem(
        id=letter.id,
        plant_id=letter.plant_id,
        plant_nickname=nickname,
        diary_id=letter.diary_id,
        diary_date=letter.diary_date,
        preview=(letter.content or "")[:100],
        generated_at=letter.generated_at,
        published_at=letter.published_at,
        is_read=letter.read_at is not None,
    )


class LetterService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list(
        self,
        user_id: UUID,
        *,
        plant_id: UUID | None = None,
        unread_only: bool = False,
        cursor: str | None = None,
        limit: int = 20,
    ) -> LetterListResponse:
        statement = visible_letters(user_id)
        if plant_id:
            statement = statement.where(Letter.plant_id == plant_id)
        if unread_only:
            statement = statement.where(Letter.read_at.is_(None))
        if cursor:
            timestamp, letter_id = decode_letter_cursor(cursor)
            statement = statement.where(
                tuple_(Letter.published_at, Letter.id) < tuple_(timestamp, letter_id)
            )
        rows = (
            await self._session.execute(
                statement.order_by(Letter.published_at.desc(), Letter.id.desc()).limit(limit + 1)
            )
        ).all()
        return LetterListResponse(
            items=[letter_item(letter, name) for letter, name in rows[:limit]],
            next_cursor=encode_letter_cursor(rows[limit - 1][0]) if len(rows) > limit else None,
        )

    async def unread_count(self, user_id: UUID, plant_id: UUID | None = None) -> int:
        statement = visible_letters(user_id).where(Letter.read_at.is_(None))
        if plant_id:
            statement = statement.where(Letter.plant_id == plant_id)
        return int(
            await self._session.scalar(select(func.count()).select_from(statement.subquery())) or 0
        )

    async def _get(
        self, user_id: UUID, letter_id: UUID, *, lock: bool = False, include_deleted: bool = False
    ):
        if lock:
            plant_id = await self._session.scalar(
                select(Letter.plant_id).where(Letter.id == letter_id)
            )
            if (
                plant_id is None
                or await lock_active_plant(self._session, user_id, plant_id) is None
            ):
                raise self._not_found()
        statement = visible_letters(user_id, include_deleted=include_deleted).where(
            Letter.id == letter_id
        )
        if lock:
            statement = statement.with_for_update(of=Letter)
        row = (await self._session.execute(statement)).one_or_none()
        if row is None:
            raise self._not_found()
        return row

    @staticmethod
    def _not_found() -> AppError:
        return AppError(
            code="LETTER_NOT_FOUND", message="편지를 찾을 수 없습니다.", status_code=404
        )

    async def detail(
        self, user_id: UUID, letter_id: UUID, *, mark_read: bool = False
    ) -> LetterDetail:
        letter, nickname = await self._get(user_id, letter_id, lock=mark_read)
        if mark_read and letter.read_at is None:
            letter.read_at = datetime.now(UTC)
            await self._session.flush()
        return LetterDetail(
            **letter_item(letter, nickname).model_dump(),
            content=letter.content,
            read_at=letter.read_at,
        )

    async def delete(self, user_id: UUID, letter_id: UUID) -> None:
        letter, _ = await self._get(user_id, letter_id, lock=True, include_deleted=True)
        if letter.deleted_at is not None:
            return
        letter.deleted_at = datetime.now(UTC)
        await self._session.execute(
            delete(Notification).where(
                Notification.user_id == user_id,
                Notification.source_type == "LETTER",
                Notification.source_id == letter_id,
            )
        )
        await self._session.flush()
