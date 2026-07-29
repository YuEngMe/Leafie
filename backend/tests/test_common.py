from datetime import UTC, datetime
from typing import Annotated
from uuid import uuid4

import pytest
from fastapi import Depends
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.dependencies import ensure_resource_owner, get_current_user
from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.main import create_app
from app.models.enums import AccountDeletionStatus
from app.schemas.common import CursorPage, CursorParams


class FakeMappingResult:
    def __init__(self, row: dict[str, object] | None) -> None:
        self._row = row

    def mappings(self) -> "FakeMappingResult":
        return self

    def one_or_none(self) -> dict[str, object] | None:
        return self._row


class FakeAccountSession:
    def __init__(self, row: dict[str, object] | None) -> None:
        self.row = row
        self.user_ids = []

    async def execute(self, _statement, parameters) -> FakeMappingResult:
        self.user_ids.append(parameters["user_id"])
        return FakeMappingResult(self.row)


def test_cursor_page_contract() -> None:
    page = CursorPage[int](
        items=[1, 2],
        next_cursor="opaque-cursor",
        has_next=True,
    )

    assert page.model_dump() == {
        "items": [1, 2],
        "next_cursor": "opaque-cursor",
        "has_next": True,
    }


def test_cursor_limit_is_bounded() -> None:
    with pytest.raises(ValidationError):
        CursorParams(limit=101)


def test_resource_owner_check_rejects_another_user() -> None:
    current_user = AuthenticatedUser(
        id=uuid4(),
        email=None,
        role="authenticated",
        claims={},
    )

    with pytest.raises(AppError) as error:
        ensure_resource_owner(uuid4(), current_user)

    assert error.value.code == "RESOURCE_FORBIDDEN"


def test_protected_route_rejects_missing_bearer_token() -> None:
    application = create_app()

    @application.get("/test-protected")
    async def protected_route(
        _current_user: Annotated[AuthenticatedUser, Depends(get_current_user)],
    ) -> dict[str, bool]:
        return {"authenticated": True}

    with TestClient(application) as client:
        response = client.get("/test-protected")

    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"


async def test_common_auth_accepts_existing_active_account() -> None:
    current_user = AuthenticatedUser(
        id=uuid4(),
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )
    session = FakeAccountSession({"deleted_at": None, "deletion_status": None})

    result = await get_current_user(current_user, session)

    assert result is current_user
    assert session.user_ids == [current_user.id]


async def test_common_auth_rejects_token_after_auth_user_is_deleted() -> None:
    current_user = AuthenticatedUser(
        id=uuid4(),
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )

    with pytest.raises(AppError) as error:
        await get_current_user(current_user, FakeAccountSession(None))

    assert error.value.code == "AUTH_REQUIRED"
    assert error.value.status_code == 401


@pytest.mark.parametrize(
    ("deletion_status", "error_code"),
    [
        (AccountDeletionStatus.PENDING, "ACCOUNT_DELETION_PENDING"),
        (AccountDeletionStatus.FAILED, "ACCOUNT_DELETION_FAILED"),
    ],
)
async def test_common_auth_blocks_accounts_during_or_after_failed_deletion(
    deletion_status: AccountDeletionStatus,
    error_code: str,
) -> None:
    current_user = AuthenticatedUser(
        id=uuid4(),
        email="leafie@example.com",
        role="authenticated",
        claims={},
    )
    session = FakeAccountSession(
        {
            "deleted_at": datetime.now(UTC),
            "deletion_status": deletion_status.value,
        }
    )

    with pytest.raises(AppError) as error:
        await get_current_user(current_user, session)

    assert error.value.code == error_code
    assert error.value.status_code == 409
