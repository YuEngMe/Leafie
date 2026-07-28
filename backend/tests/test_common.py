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
from app.schemas.common import CursorPage, CursorParams


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
