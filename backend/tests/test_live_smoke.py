import httpx
import pytest

from app.core.config import Settings
from tools.smoke_live import SmokeError, request, validate_target


def settings(**changes):
    return Settings(
        _env_file=None,
        supabase_url="https://test.supabase.co",
        supabase_secret_key="test-secret",
        **changes,
    )


@pytest.mark.parametrize(
    "api_url",
    [
        "https://api.example.com",
        "http://localhost.example.com",
        "http://user:password@localhost:8000",
        "http://localhost:8000?token=private",
    ],
)
def test_live_smoke_rejects_nonlocal_or_credentialed_api(api_url):
    with pytest.raises(SmokeError):
        validate_target(settings(), api_url, True)


def test_live_smoke_requires_explicit_opt_in_and_local_environment():
    with pytest.raises(SmokeError):
        validate_target(settings(), "http://localhost:8000", False)
    with pytest.raises(SmokeError):
        validate_target(settings(app_env="production"), "http://localhost:8000", True)
    with pytest.raises(SmokeError):
        validate_target(settings(letter_generation_enabled=True), "http://localhost:8000", True)
    validate_target(settings(), "http://127.0.0.1:8000", True)


def test_live_smoke_http_errors_do_not_disclose_response_or_signed_url():
    with httpx.Client(
        transport=httpx.MockTransport(lambda _: httpx.Response(403, text="private-secret"))
    ) as client:
        with pytest.raises(SmokeError) as error:
            request(client, "GET", "https://test.example.com?token=private-secret")
    assert str(error.value) == "HTTP_403: expected (200,)"
    assert "private-secret" not in str(error.value)
