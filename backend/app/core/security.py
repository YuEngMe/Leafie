import asyncio
from dataclasses import dataclass
from time import monotonic
from typing import Any
from uuid import UUID

import httpx
import jwt
from jwt import PyJWK

from app.core.config import Settings
from app.core.errors import AppError

JWKS_CACHE_SECONDS = 600
SUPPORTED_ALGORITHMS = ("ES256",)


@dataclass(frozen=True, slots=True)
class AuthenticatedUser:
    id: UUID
    email: str | None
    role: str | None
    claims: dict[str, Any]


class SupabaseJWTVerifier:
    def __init__(
        self,
        settings: Settings,
        *,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._jwks_url = settings.resolved_supabase_jwks_url
        self._issuer = settings.resolved_supabase_jwt_issuer
        self._audience = settings.supabase_jwt_audience
        self._http_client = http_client
        self._cached_keys: dict[str, Any] = {}
        self._cache_expires_at = 0.0
        self._cache_lock = asyncio.Lock()

    async def verify(self, token: str) -> AuthenticatedUser:
        if not self._jwks_url or not self._issuer:
            raise AppError(
                code="AUTH_CONFIGURATION_ERROR",
                message="인증 서버 설정이 완료되지 않았습니다.",
                status_code=500,
            )

        try:
            header = jwt.get_unverified_header(token)
            algorithm = header.get("alg")
            key_id = header.get("kid")
            if algorithm not in SUPPORTED_ALGORITHMS or not key_id:
                raise jwt.InvalidTokenError("Unsupported signing key")

            signing_key = await self._get_signing_key(key_id)
            claims = jwt.decode(
                token,
                signing_key,
                algorithms=[algorithm],
                audience=self._audience,
                issuer=self._issuer,
                options={"require": ["exp", "iat", "sub", "aud", "iss"]},
            )
            user_id = UUID(claims["sub"])
        except jwt.ExpiredSignatureError as exc:
            raise AppError(
                code="TOKEN_EXPIRED",
                message="인증이 만료되었습니다.",
                status_code=401,
                headers={"WWW-Authenticate": "Bearer"},
            ) from exc
        except (jwt.PyJWTError, ValueError, KeyError) as exc:
            raise AppError(
                code="AUTH_REQUIRED",
                message="유효한 인증 정보가 필요합니다.",
                status_code=401,
                headers={"WWW-Authenticate": "Bearer"},
            ) from exc

        return AuthenticatedUser(
            id=user_id,
            email=claims.get("email"),
            role=claims.get("role"),
            claims=claims,
        )

    async def close(self) -> None:
        if self._http_client is not None:
            await self._http_client.aclose()
            self._http_client = None

    async def _get_signing_key(self, key_id: str) -> Any:
        if monotonic() >= self._cache_expires_at or key_id not in self._cached_keys:
            await self._refresh_keys(force=key_id not in self._cached_keys)

        signing_key = self._cached_keys.get(key_id)
        if signing_key is None:
            await self._refresh_keys(force=True)
            signing_key = self._cached_keys.get(key_id)
        if signing_key is None:
            raise jwt.InvalidTokenError("Signing key not found")
        return signing_key

    async def _refresh_keys(self, *, force: bool = False) -> None:
        async with self._cache_lock:
            if not force and monotonic() < self._cache_expires_at and self._cached_keys:
                return

            if self._http_client is None:
                self._http_client = httpx.AsyncClient(timeout=5.0)

            try:
                response = await self._http_client.get(self._jwks_url)
                response.raise_for_status()
                jwks = response.json()
                keys = {
                    item["kid"]: PyJWK.from_dict(item).key
                    for item in jwks.get("keys", [])
                    if item.get("kid") and item.get("alg") in SUPPORTED_ALGORITHMS
                }
            except (httpx.HTTPError, ValueError, KeyError) as exc:
                raise jwt.InvalidTokenError("Unable to load signing keys") from exc

            if not keys:
                raise jwt.InvalidTokenError("No supported signing keys")

            self._cached_keys = keys
            self._cache_expires_at = monotonic() + JWKS_CACHE_SECONDS
