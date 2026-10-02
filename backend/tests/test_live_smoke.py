from datetime import UTC, datetime

import httpx
import pytest
from PIL import Image

from app.core.config import Settings
from tools.smoke_live import (
    SmokeError,
    read_photo,
    request,
    validate_target,
    verify_unpublished_letter,
)


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


def test_letter_smoke_requires_enabled_generation_and_explicit_paid_opt_in():
    enabled = settings(letter_generation_enabled=True)
    with pytest.raises(SmokeError):
        validate_target(enabled, "http://localhost:8000", True, letter=True)
    with pytest.raises(SmokeError):
        validate_target(settings(), "http://localhost:8000", True, letter=True, allow_paid=True)
    validate_target(enabled, "http://localhost:8000", True, letter=True, allow_paid=True)


def test_photo_uses_api_signature_detection_not_pillow_format_label(tmp_path, monkeypatch):
    path = tmp_path / "photo.dat"
    Image.new("RGB", (16, 16), "green").save(path, format="JPEG")
    real_open = Image.open

    def open_mpo(*args, **kwargs):
        image = real_open(*args, **kwargs)
        image.format = "MPO"
        return image

    monkeypatch.setattr(Image, "open", open_mpo)
    data, mime = read_photo(path)
    assert data == path.read_bytes()
    assert mime == "image/jpeg"


def test_invalid_photo_rejected_before_creating_accounts(tmp_path):
    path = tmp_path / "photo.jpg"
    path.write_bytes(b"not an image")
    with pytest.raises(SmokeError, match="Photo format"):
        read_photo(path)


@pytest.mark.parametrize("published", [False, True])
def test_visibility_failure_is_only_tolerated_after_publication(monkeypatch, published):
    monkeypatch.setattr(
        "tools.smoke_live.letter_snapshot",
        lambda *_: {"published_at": datetime.now(UTC) if published else None},
    )
    with httpx.Client(transport=httpx.MockTransport(lambda _: httpx.Response(200))) as client:
        args = (
            settings(),
            client,
            "http://localhost/api/v1",
            {},
            "test-diary",
            "http://localhost/api/v1/letters/test-letter",
        )
        if published:
            verify_unpublished_letter(*args)
        else:
            with pytest.raises(SmokeError, match="HTTP_200"):
                verify_unpublished_letter(*args)
