from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, Protocol
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import func, select, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.integrations.storage import StorageGateway
from app.models.diagnosis import Diagnosis
from app.models.enums import MediaPurpose, MediaStatus
from app.models.media import MediaFile
from app.models.plant import Plant, PlantDiary
from app.models.user import UserProfile
from app.schemas.user import (
    SelectedPlantResponse,
    UserProfileResponse,
    UserProfileUpdate,
    UserStatsResponse,
)

AUTH_USER_QUERY = text(
    """
    SELECT
        users.id,
        users.email,
        users.email_confirmed_at,
        users.created_at,
        users.raw_user_meta_data,
        COALESCE(
            array_agg(DISTINCT identities.provider)
                FILTER (WHERE identities.provider IS NOT NULL),
            ARRAY[]::text[]
        ) AS auth_providers
    FROM auth.users AS users
    LEFT JOIN auth.identities AS identities ON identities.user_id = users.id
    WHERE users.id = :user_id
    GROUP BY
        users.id,
        users.email,
        users.email_confirmed_at,
        users.created_at,
        users.raw_user_meta_data
    """
)
RECENT_AUTH_METHODS = frozenset({"password", "oauth", "otp", "totp", "magiclink", "sso/saml"})


@dataclass(frozen=True, slots=True)
class AuthUserRecord:
    id: UUID
    email: str | None
    email_verified_at: datetime | None
    created_at: datetime
    raw_user_meta_data: dict[str, Any]
    auth_providers: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class UserStats:
    plant_count: int
    diary_count: int
    diagnosis_count: int


class UserRepository(Protocol):
    async def get_auth_user(self, user_id: UUID) -> AuthUserRecord | None: ...

    async def get_profile(self, user_id: UUID) -> UserProfile | None: ...

    async def create_profile_if_missing(self, profile: UserProfile) -> None: ...

    async def get_profile_media_path(self, media_file_id: UUID, user_id: UUID) -> str | None: ...

    async def plant_is_owned(self, plant_id: UUID, user_id: UUID) -> bool: ...

    async def get_stats(self, user_id: UUID) -> UserStats: ...


class SQLAlchemyUserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_auth_user(self, user_id: UUID) -> AuthUserRecord | None:
        result = await self._session.execute(AUTH_USER_QUERY, {"user_id": user_id})
        row = result.mappings().one_or_none()
        if row is None:
            return None
        return AuthUserRecord(
            id=row["id"],
            email=row["email"],
            email_verified_at=row["email_confirmed_at"],
            created_at=row["created_at"],
            raw_user_meta_data=row["raw_user_meta_data"] or {},
            auth_providers=tuple(sorted(row["auth_providers"] or ())),
        )

    async def get_profile(self, user_id: UUID) -> UserProfile | None:
        return await self._session.scalar(select(UserProfile).where(UserProfile.user_id == user_id))

    async def create_profile_if_missing(self, profile: UserProfile) -> None:
        statement = (
            insert(UserProfile)
            .values(
                user_id=profile.user_id,
                nickname=profile.nickname,
                timezone=profile.timezone,
            )
            .on_conflict_do_nothing(index_elements=[UserProfile.user_id])
        )
        await self._session.execute(statement)
        await self._session.flush()

    async def get_profile_media_path(self, media_file_id: UUID, user_id: UUID) -> str | None:
        statement = select(MediaFile.object_path).where(
            MediaFile.id == media_file_id,
            MediaFile.user_id == user_id,
            MediaFile.purpose == MediaPurpose.USER_PROFILE.value,
            MediaFile.status == MediaStatus.READY.value,
            MediaFile.deleted_at.is_(None),
        )
        return await self._session.scalar(statement)

    async def plant_is_owned(self, plant_id: UUID, user_id: UUID) -> bool:
        statement = select(Plant.id).where(
            Plant.id == plant_id,
            Plant.user_id == user_id,
            Plant.deleted_at.is_(None),
        )
        return await self._session.scalar(statement) is not None

    async def get_stats(self, user_id: UUID) -> UserStats:
        plant_count = await self._session.scalar(
            select(func.count(Plant.id)).where(
                Plant.user_id == user_id,
                Plant.deleted_at.is_(None),
            )
        )
        diary_count = await self._session.scalar(
            select(func.count(PlantDiary.id))
            .join(Plant, Plant.id == PlantDiary.plant_id)
            .where(
                Plant.user_id == user_id,
                Plant.deleted_at.is_(None),
                PlantDiary.deleted_at.is_(None),
            )
        )
        diagnosis_count = await self._session.scalar(
            select(func.count(Diagnosis.id))
            .join(Plant, Plant.id == Diagnosis.plant_id)
            .where(
                Plant.user_id == user_id,
                Plant.deleted_at.is_(None),
                Diagnosis.deleted_at.is_(None),
            )
        )
        return UserStats(
            plant_count=int(plant_count or 0),
            diary_count=int(diary_count or 0),
            diagnosis_count=int(diagnosis_count or 0),
        )


class UserService:
    def __init__(
        self,
        repository: UserRepository,
        storage: StorageGateway,
        *,
        profile_url_expires_seconds: int = 300,
        reauth_max_age_seconds: int = 300,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._profile_url_expires_seconds = profile_url_expires_seconds
        self._reauth_max_age_seconds = reauth_max_age_seconds

    async def get_me(self, user_id: UUID) -> UserProfileResponse:
        auth_user, profile = await self._get_active_user(user_id)
        return await self._build_response(auth_user, profile)

    async def update_me(
        self,
        user_id: UUID,
        request: UserProfileUpdate,
    ) -> UserProfileResponse:
        auth_user, profile = await self._get_active_user(user_id)
        fields = request.model_fields_set

        if "profile_media_file_id" in fields:
            media_file_id = request.profile_media_file_id
            if media_file_id is not None:
                await self._require_profile_media(media_file_id, user_id)
            profile.profile_media_file_id = media_file_id
        if "nickname" in fields:
            assert request.nickname is not None
            profile.nickname = request.nickname
        if "bio" in fields:
            profile.bio = request.bio
        if "timezone" in fields:
            assert request.timezone is not None
            profile.timezone = request.timezone

        return await self._build_response(auth_user, profile)

    async def update_selected_plant(
        self,
        user_id: UUID,
        selected_plant_id: UUID | None,
    ) -> SelectedPlantResponse:
        _, profile = await self._get_active_user(user_id)
        if selected_plant_id is not None and not await self._repository.plant_is_owned(
            selected_plant_id, user_id
        ):
            raise AppError(
                code="PLANT_NOT_FOUND",
                message="식물을 찾을 수 없습니다.",
                status_code=404,
            )
        profile.selected_plant_id = selected_plant_id
        return SelectedPlantResponse(selected_plant_id=selected_plant_id)

    async def get_stats(self, user_id: UUID) -> UserStatsResponse:
        await self._get_active_user(user_id)
        stats = await self._repository.get_stats(user_id)
        return UserStatsResponse(
            plant_count=stats.plant_count,
            diary_count=stats.diary_count,
            diagnosis_count=stats.diagnosis_count,
        )

    async def request_account_deletion(
        self,
        user_id: UUID,
        claims: dict[str, Any],
    ) -> bool:
        _, profile = await self._get_user(user_id)
        self._require_recent_authentication(claims)
        if profile.deleted_at is not None:
            return False
        profile.deleted_at = datetime.now(UTC)
        return True

    async def _get_active_user(self, user_id: UUID) -> tuple[AuthUserRecord, UserProfile]:
        auth_user, profile = await self._get_user(user_id)
        if profile.deleted_at is not None:
            raise AppError(
                code="ACCOUNT_DELETION_PENDING",
                message="계정 삭제가 진행 중입니다.",
                status_code=409,
            )
        return auth_user, profile

    async def _get_user(self, user_id: UUID) -> tuple[AuthUserRecord, UserProfile]:
        auth_user = await self._repository.get_auth_user(user_id)
        if auth_user is None:
            raise AppError(
                code="AUTH_REQUIRED",
                message="인증 사용자를 찾을 수 없습니다.",
                status_code=401,
            )
        if auth_user.email is None:
            raise AppError(
                code="SOCIAL_EMAIL_REQUIRED",
                message="이메일 제공 동의가 필요합니다.",
                status_code=403,
            )
        if auth_user.email_verified_at is None:
            raise AppError(
                code="EMAIL_NOT_VERIFIED",
                message="이메일 인증이 필요합니다.",
                status_code=403,
            )

        profile = await self._repository.get_profile(user_id)
        if profile is None:
            await self._repository.create_profile_if_missing(
                UserProfile(
                    user_id=user_id,
                    nickname=default_nickname(auth_user),
                    timezone="Asia/Seoul",
                )
            )
            profile = await self._repository.get_profile(user_id)
        if profile is None:
            raise AppError(
                code="PROFILE_INITIALIZATION_FAILED",
                message="사용자 프로필을 생성하지 못했습니다.",
                status_code=500,
            )
        return auth_user, profile

    async def _build_response(
        self,
        auth_user: AuthUserRecord,
        profile: UserProfile,
    ) -> UserProfileResponse:
        profile_image_url = None
        if profile.profile_media_file_id is not None:
            object_path = await self._repository.get_profile_media_path(
                profile.profile_media_file_id,
                profile.user_id,
            )
            if object_path is not None:
                profile_image_url = await self._storage.create_signed_download_url(
                    object_path,
                    expires_in=self._profile_url_expires_seconds,
                )

        timezone = ZoneInfo(profile.timezone)
        created_at = auth_user.created_at
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=UTC)
        gardener_days = max(
            (datetime.now(timezone).date() - created_at.astimezone(timezone).date()).days,
            0,
        )
        providers = sorted(set(auth_user.auth_providers))
        assert auth_user.email is not None
        assert auth_user.email_verified_at is not None
        return UserProfileResponse(
            user_id=auth_user.id,
            email=auth_user.email,
            email_verified_at=auth_user.email_verified_at,
            auth_providers=providers,
            can_change_password="email" in providers,
            nickname=profile.nickname,
            bio=profile.bio,
            profile_media_file_id=profile.profile_media_file_id,
            profile_image_url=profile_image_url,
            timezone=profile.timezone,
            selected_plant_id=profile.selected_plant_id,
            gardener_days=gardener_days,
        )

    async def _require_profile_media(self, media_file_id: UUID, user_id: UUID) -> str:
        object_path = await self._repository.get_profile_media_path(media_file_id, user_id)
        if object_path is None:
            raise AppError(
                code="MEDIA_FILE_NOT_FOUND",
                message="사용 가능한 프로필 이미지를 찾을 수 없습니다.",
                status_code=404,
            )
        return object_path

    def _require_recent_authentication(self, claims: dict[str, Any]) -> None:
        amr = claims.get("amr")
        if not isinstance(amr, list):
            raise AppError(
                code="RECENT_AUTH_REQUIRED",
                message="계정 삭제 전에 다시 로그인해 주세요.",
                status_code=401,
            )

        authentication_times = [
            float(item["timestamp"])
            for item in amr
            if isinstance(item, dict)
            and item.get("method") in RECENT_AUTH_METHODS
            and isinstance(item.get("timestamp"), (int, float))
        ]
        if not authentication_times:
            raise AppError(
                code="RECENT_AUTH_REQUIRED",
                message="계정 삭제 전에 다시 로그인해 주세요.",
                status_code=401,
            )

        age_seconds = datetime.now(UTC).timestamp() - max(authentication_times)
        if age_seconds < -60 or age_seconds > self._reauth_max_age_seconds:
            raise AppError(
                code="RECENT_AUTH_REQUIRED",
                message="계정 삭제 전에 다시 로그인해 주세요.",
                status_code=401,
            )


def default_nickname(auth_user: AuthUserRecord) -> str:
    metadata = auth_user.raw_user_meta_data
    for key in ("nickname", "full_name", "name", "preferred_username"):
        value = metadata.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()[:100]
    if auth_user.email and auth_user.email.partition("@")[0].strip():
        return auth_user.email.partition("@")[0].strip()[:100]
    return "새싹집사"
