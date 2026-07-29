from collections.abc import AsyncIterator
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.security import AuthenticatedUser
from app.integrations.queue import JobQueue
from app.integrations.storage import StorageGateway
from app.models.enums import AccountDeletionStatus

bearer_scheme = HTTPBearer(auto_error=False)
ACCOUNT_ACCESS_QUERY = text(
    """
    SELECT profiles.deleted_at, profiles.deletion_status
    FROM auth.users AS users
    LEFT JOIN public.user_profiles AS profiles ON profiles.user_id = users.id
    WHERE users.id = :user_id
    """
)


async def get_database_session(request: Request) -> AsyncIterator[AsyncSession]:
    async for session in request.app.state.database.session():
        yield session


async def verify_access_token(
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


async def get_current_user(
    authenticated_user: Annotated[AuthenticatedUser, Depends(verify_access_token)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> AuthenticatedUser:
    result = await session.execute(
        ACCOUNT_ACCESS_QUERY,
        {"user_id": authenticated_user.id},
    )
    account = result.mappings().one_or_none()
    if account is None:
        raise AppError(
            code="AUTH_REQUIRED",
            message="유효한 인증 사용자를 찾을 수 없습니다.",
            status_code=401,
            headers={"WWW-Authenticate": "Bearer"},
        )

    deletion_status = account["deletion_status"]
    if deletion_status == AccountDeletionStatus.FAILED:
        raise AppError(
            code="ACCOUNT_DELETION_FAILED",
            message="계정 삭제를 완료하지 못했습니다. 관리자 확인이 필요합니다.",
            status_code=409,
        )
    if account["deleted_at"] is not None or deletion_status is not None:
        raise AppError(
            code="ACCOUNT_DELETION_PENDING",
            message="계정 삭제가 진행 중입니다.",
            status_code=409,
        )

    return authenticated_user


def get_storage_gateway(request: Request) -> StorageGateway:
    return request.app.state.storage


def get_job_queue(request: Request) -> JobQueue:
    return request.app.state.queue


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
