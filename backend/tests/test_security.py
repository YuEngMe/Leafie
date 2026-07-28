from datetime import UTC, datetime, timedelta
from uuid import uuid4

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec

from app.core.config import Settings
from app.core.errors import AppError
from app.core.security import SupabaseJWTVerifier

PROJECT_URL = "https://leafie-test.supabase.co"
ISSUER = f"{PROJECT_URL}/auth/v1"
JWKS_URL = f"{ISSUER}/.well-known/jwks.json"
KEY_ID = "test-key"


def build_key_pair() -> tuple[ec.EllipticCurvePrivateKey, dict[str, str]]:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_jwk = jwt.algorithms.ECAlgorithm.to_jwk(private_key.public_key(), as_dict=True)
    public_jwk.update({"kid": KEY_ID, "alg": "ES256", "use": "sig"})
    return private_key, public_jwk


def build_token(
    private_key: ec.EllipticCurvePrivateKey,
    *,
    expires_at: datetime | None = None,
    issuer: str = ISSUER,
    audience: str = "authenticated",
) -> tuple[str, str]:
    now = datetime.now(UTC)
    user_id = str(uuid4())
    token = jwt.encode(
        {
            "sub": user_id,
            "email": "leafie@example.com",
            "role": "authenticated",
            "iss": issuer,
            "aud": audience,
            "iat": now,
            "exp": expires_at or now + timedelta(minutes=5),
        },
        private_key,
        algorithm="ES256",
        headers={"kid": KEY_ID},
    )
    return token, user_id


def build_verifier(public_jwk: dict[str, str]) -> SupabaseJWTVerifier:
    def jwks_handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url) == JWKS_URL
        return httpx.Response(200, json={"keys": [public_jwk]})

    settings = Settings(
        _env_file=None,
        supabase_url=PROJECT_URL,
        supabase_jwt_audience="authenticated",
    )
    client = httpx.AsyncClient(transport=httpx.MockTransport(jwks_handler))
    return SupabaseJWTVerifier(settings, http_client=client)


async def test_verifies_supabase_es256_token() -> None:
    private_key, public_jwk = build_key_pair()
    token, user_id = build_token(private_key)
    verifier = build_verifier(public_jwk)

    user = await verifier.verify(token)
    await verifier.close()

    assert str(user.id) == user_id
    assert user.email == "leafie@example.com"
    assert user.role == "authenticated"


async def test_rejects_expired_token() -> None:
    private_key, public_jwk = build_key_pair()
    token, _ = build_token(
        private_key,
        expires_at=datetime.now(UTC) - timedelta(seconds=1),
    )
    verifier = build_verifier(public_jwk)

    with pytest.raises(AppError) as error:
        await verifier.verify(token)
    await verifier.close()

    assert error.value.code == "TOKEN_EXPIRED"
    assert error.value.status_code == 401


@pytest.mark.parametrize(
    ("issuer", "audience"),
    [
        ("https://wrong.example.com/auth/v1", "authenticated"),
        (ISSUER, "wrong-audience"),
    ],
)
async def test_rejects_wrong_issuer_or_audience(
    issuer: str,
    audience: str,
) -> None:
    private_key, public_jwk = build_key_pair()
    token, _ = build_token(private_key, issuer=issuer, audience=audience)
    verifier = build_verifier(public_jwk)

    with pytest.raises(AppError) as error:
        await verifier.verify(token)
    await verifier.close()

    assert error.value.code == "AUTH_REQUIRED"
    assert error.value.status_code == 401
