from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import httpx
import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.core.config import Settings
from app.core.errors import AppError
from app.integrations.auth import SupabaseAuthAdminGateway
from app.main import create_app
from app.models.user import UserProfile
from app.schemas.queue import JobType, QueueJob
from app.schemas.user import UserProfileUpdate
from app.services.user import AuthUserRecord, UserService, UserStats
from app.tasks.account import AccountDeleteHandler


class FakeUserRepository:
    def __init__(self, auth_user: AuthUserRecord) -> None:
        self.auth_user = auth_user
        self.profile: UserProfile | None = None
        self.profile_media: dict[UUID, str] = {}
        self.owned_plants: set[UUID] = set()
        self.stats = UserStats(plant_count=2, diary_count=5, diagnosis_count=1)
        self.create_calls = 0

    async def get_auth_user(self, user_id: UUID) -> AuthUserRecord | None:
        return self.auth_user if self.auth_user.id == user_id else None

    async def get_profile(self, user_id: UUID) -> UserProfile | None:
        if self.profile is not None and self.profile.user_id == user_id:
            return self.profile
        return None

    async def create_profile_if_missing(self, profile: UserProfile) -> None:
        self.create_calls += 1
        if self.profile is None:
            self.profile = profile

    async def get_profile_media_path(self, media_file_id: UUID, user_id: UUID) -> str | None:
        if user_id != self.auth_user.id:
            return None
        return self.profile_media.get(media_file_id)

    async def plant_is_owned(self, plant_id: UUID, user_id: UUID) -> bool:
        return user_id == self.auth_user.id and plant_id in self.owned_plants

    async def get_stats(self, user_id: UUID) -> UserStats:
        assert user_id == self.auth_user.id
        return self.stats


class FakeStorage:
    bucket_name = "leafie-media"

    def __init__(self) -> None:
        self.signed: list[tuple[str, int]] = []
        self.deleted: list[str] = []

    async def create_signed_download_url(self, object_path: str, *, expires_in: int) -> str:
        self.signed.append((object_path, expires_in))
        return f"https://storage.example/{object_path}"

    async def delete_object(self, object_path: str) -> None:
        self.deleted.append(object_path)


class FakeAuthAdmin:
    def __init__(self) -> None:
        self.deleted: list[UUID] = []

    async def delete_user(self, user_id: UUID) -> None:
        self.deleted.append(user_id)


class FakeAccountRepository:
    def __init__(self, paths: list[str]) -> None:
        self.paths = paths

    async def list_media_paths(self, _user_id: UUID) -> list[str]:
        return self.paths


def make_auth_user(**overrides: object) -> AuthUserRecord:
    values = {
        "id": uuid4(),
        "email": "leafie@example.com",
        "email_verified_at": datetime.now(UTC),
        "created_at": datetime.now(UTC) - timedelta(days=10),
        "raw_user_meta_data": {"full_name": "잎새 집사"},
        "auth_providers": ("google", "email"),
    }
    values.update(overrides)
    return AuthUserRecord(**values)


def build_service(
    auth_user: AuthUserRecord | None = None,
) -> tuple[UserService, FakeUserRepository, FakeStorage]:
    repository = FakeUserRepository(auth_user or make_auth_user())
    storage = FakeStorage()
    return UserService(repository, storage), repository, storage


async def test_get_me_idempotently_creates_profile_from_auth_identity() -> None:
    service, repository, _ = build_service()

    first = await service.get_me(repository.auth_user.id)
    second = await service.get_me(repository.auth_user.id)

    assert first.nickname == "잎새 집사"
    assert first.auth_providers == ["email", "google"]
    assert first.can_change_password is True
    assert first.gardener_days == 10
    assert second.user_id == first.user_id
    assert repository.create_calls == 1


async def test_update_profile_requires_owned_ready_profile_media() -> None:
    service, repository, storage = build_service()
    await service.get_me(repository.auth_user.id)
    media_file_id = uuid4()

    with pytest.raises(AppError) as error:
        await service.update_me(
            repository.auth_user.id,
            UserProfileUpdate(profile_media_file_id=media_file_id),
        )
    assert error.value.code == "MEDIA_FILE_NOT_FOUND"

    repository.profile_media[media_file_id] = f"user-profile/{media_file_id}.jpg"
    response = await service.update_me(
        repository.auth_user.id,
        UserProfileUpdate(
            nickname="  초록이  ",
            bio="반가워요",
            profile_media_file_id=media_file_id,
            timezone="Asia/Seoul",
        ),
    )

    assert response.nickname == "초록이"
    assert response.profile_media_file_id == media_file_id
    assert response.profile_image_url is not None
    assert storage.signed == [(repository.profile_media[media_file_id], 300)]


async def test_selected_plant_must_belong_to_current_user() -> None:
    service, repository, _ = build_service()
    plant_id = uuid4()

    with pytest.raises(AppError) as error:
        await service.update_selected_plant(repository.auth_user.id, plant_id)
    assert error.value.code == "PLANT_NOT_FOUND"

    repository.owned_plants.add(plant_id)
    response = await service.update_selected_plant(repository.auth_user.id, plant_id)

    assert response.selected_plant_id == plant_id
    assert repository.profile is not None
    assert repository.profile.selected_plant_id == plant_id


async def test_stats_return_active_user_counts() -> None:
    service, repository, _ = build_service()

    response = await service.get_stats(repository.auth_user.id)

    assert response.model_dump() == {
        "plant_count": 2,
        "diary_count": 5,
        "diagnosis_count": 1,
    }


async def test_account_deletion_requires_recent_token_and_is_idempotent() -> None:
    service, repository, _ = build_service()
    old_auth_time = int((datetime.now(UTC) - timedelta(minutes=10)).timestamp())

    with pytest.raises(AppError) as error:
        await service.request_account_deletion(
            repository.auth_user.id,
            {"amr": [{"method": "password", "timestamp": old_auth_time}]},
        )
    assert error.value.code == "RECENT_AUTH_REQUIRED"

    recent_auth_time = int(datetime.now(UTC).timestamp())
    recent_claims = {"amr": [{"method": "password", "timestamp": recent_auth_time}]}
    assert await service.request_account_deletion(repository.auth_user.id, recent_claims)
    assert not await service.request_account_deletion(repository.auth_user.id, recent_claims)


async def test_account_deletion_does_not_treat_token_refresh_as_reauthentication() -> None:
    service, repository, _ = build_service()
    now = int(datetime.now(UTC).timestamp())

    with pytest.raises(AppError) as error:
        await service.request_account_deletion(
            repository.auth_user.id,
            {"iat": now, "amr": [{"method": "token_refresh", "timestamp": now}]},
        )

    assert error.value.code == "RECENT_AUTH_REQUIRED"


def test_profile_update_validates_required_fields_and_timezone() -> None:
    with pytest.raises(ValidationError):
        UserProfileUpdate.model_validate({"nickname": None})
    with pytest.raises(ValidationError):
        UserProfileUpdate.model_validate({"timezone": "Not/A-Timezone"})


async def test_account_delete_handler_removes_storage_then_auth_user() -> None:
    user_id = uuid4()
    storage = FakeStorage()
    auth_admin = FakeAuthAdmin()
    handler = AccountDeleteHandler(
        FakeAccountRepository(["one.jpg", "two.jpg"]),
        storage,
        auth_admin,
    )

    await handler(
        QueueJob(
            job_type=JobType.ACCOUNT_DELETE,
            resource_id=user_id,
            trace_id="req_account_delete_test",
        )
    )

    assert storage.deleted == ["one.jpg", "two.jpg"]
    assert auth_admin.deleted == [user_id]


async def test_auth_admin_delete_uses_server_secret_and_treats_missing_as_success() -> None:
    user_id = uuid4()

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["apikey"] == "test-secret"
        assert request.headers["Authorization"] == "Bearer test-secret"
        assert str(request.url).endswith(f"/auth/v1/admin/users/{user_id}")
        assert request.content == b'{"should_soft_delete":false}'
        return httpx.Response(404)

    gateway = SupabaseAuthAdminGateway(
        Settings(
            _env_file=None,
            supabase_url="https://leafie-test.supabase.co",
            supabase_secret_key="test-secret",
        ),
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )

    await gateway.delete_user(user_id)
    await gateway.close()


def test_user_routes_require_authentication_and_are_in_openapi() -> None:
    application = create_app()

    with TestClient(application) as client:
        response = client.get("/api/v1/users/me")
        openapi = client.get("/api/v1/openapi.json").json()

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"
    assert "/api/v1/users/me" in openapi["paths"]
    assert "/api/v1/users/me/selected-plant" in openapi["paths"]
    assert "/api/v1/users/me/stats" in openapi["paths"]
