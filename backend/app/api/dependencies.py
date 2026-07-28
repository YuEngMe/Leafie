from collections.abc import AsyncIterator
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.integrations.storage import StorageGateway

bearer_scheme = HTTPBearer(auto_error=False)


async def get_database_session(request: Request) -> AsyncIterator[AsyncSession]:
    async for session in request.app.state.database.session():
        yield session


async def get_current_user(
    request: Request,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer_scheme),
    ],
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AppError(
            code="AUTH_REQUIRED",
            message="인증이 필요합니다.",
            status_code=401,
            headers={"WWW-Authenticate": "Bearer"},
        )

    return await request.app.state.jwt_verifier.verify(credentials.credentials)


def get_storage_gateway(request: Request) -> StorageGateway:
    return request.app.state.storage


def ensure_resource_owner(
    owner_id: UUID,
    current_user: AuthenticatedUser,
) -> None:
    if owner_id != current_user.id:
        raise AppError(
            code="RESOURCE_FORBIDDEN",
            message="해당 리소스에 접근할 수 없습니다.",
            status_code=403,
        )
