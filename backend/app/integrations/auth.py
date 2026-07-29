import logging
from typing import Protocol
from uuid import UUID

import httpx

from app.core.config import Settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)


class AuthAdminGateway(Protocol):
    async def delete_user(self, user_id: UUID) -> None: ...


class SupabaseAuthAdminGateway:
    def __init__(
        self,
        settings: Settings,
        *,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._url = settings.supabase_url
        self._secret_key = settings.supabase_secret_key
        self._http_client = http_client
        self._owns_client = http_client is None

    async def delete_user(self, user_id: UUID) -> None:
        if not self._url or not self._secret_key:
            raise AppError(
                code="AUTH_ADMIN_NOT_CONFIGURED",
                message="인증 관리자 설정이 완료되지 않았습니다.",
                status_code=503,
            )
        if self._http_client is None:
            self._http_client = httpx.AsyncClient(timeout=10.0)
            self._owns_client = True

        try:
            response = await self._http_client.request(
                "DELETE",
                f"{self._url.rstrip('/')}/auth/v1/admin/users/{user_id}",
                headers={
                    "apikey": self._secret_key,
                    "Authorization": f"Bearer {self._secret_key}",
                },
                json={"should_soft_delete": False},
            )
        except httpx.HTTPError as exc:
            raise self._unavailable_error() from exc

        if response.status_code == 404:
            return
        if response.is_error:
            logger.error(
                "Supabase Auth Admin delete failed user_id=%s status_code=%s",
                user_id,
                response.status_code,
            )
            raise self._unavailable_error()

    async def close(self) -> None:
        if self._http_client is not None and self._owns_client:
            await self._http_client.aclose()
            self._http_client = None

    @staticmethod
    def _unavailable_error() -> AppError:
        return AppError(
            code="AUTH_ADMIN_UNAVAILABLE",
            message="인증 사용자 삭제를 완료할 수 없습니다.",
            status_code=503,
        )
