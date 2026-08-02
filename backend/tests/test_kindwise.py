from io import BytesIO

import httpx
import pytest
from PIL import Image

from app.core.config import Settings
from app.integrations.diagnosis import (
    DiagnosisPermanentError,
    DiagnosisRetakeError,
    DiagnosisTransientError,
)
from app.integrations.kindwise import KindwiseDiagnosisProvider


def _image() -> bytes:
    image = Image.new("RGB", (700, 700), (70, 150, 60))
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


def _settings() -> Settings:
    return Settings(
        _env_file=None,
        kindwise_api_key="test-key",
        kindwise_base_url="https://kindwise.test/v3",
    )


async def test_kindwise_provider_normalizes_health_result() -> None:
    async def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Api-Key"] == "test-key"
        assert request.url.path == "/v3/health_assessment"
        assert request.url.params["language"] == "ko"
        body = await request.aread()
        assert b'name="images"' in body
        assert b'name="disease_model"' in body
        assert b"full" in body
        return httpx.Response(
            200,
            json={
                "access_token": "assessment-1",
                "model_version": "health-v3",
                "result": {
                    "is_plant": {"binary": True},
                    "is_healthy": {"binary": False},
                    "disease": {
                        "suggestions": [
                            {
                                "name": "water deficiency",
                                "probability": 0.88,
                                "details": {
                                    "local_name": "물 부족",
                                    "is_harmful": True,
                                    "treatment": {
                                        "prevention": ["흙이 마른 뒤 물을 충분히 주세요."],
                                        "biological": ["직사광선을 피해주세요."],
                                        "chemical": ["저장하지 않을 항목"],
                                    },
                                },
                            }
                        ]
                    },
                },
            },
        )

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = KindwiseDiagnosisProvider(_settings(), client)

    result = await provider.diagnose(_image(), "image/png", {})

    assert result.overall_condition == "UNHEALTHY"
    assert result.possible_causes[0].name == "물 부족"
    assert result.possible_causes[0].confidence == 0.88
    assert result.observations == ["물 부족 관련 징후가 감지되었습니다."]
    assert result.care_suggestions == [
        "흙이 마른 뒤 물을 충분히 주세요.",
        "직사광선을 피해주세요.",
    ]
    assert result.response_id == "assessment-1"
    await client.aclose()


async def test_kindwise_provider_requests_retake_when_plant_is_not_visible() -> None:
    transport = httpx.MockTransport(
        lambda _request: httpx.Response(
            200,
            json={
                "result": {
                    "is_plant": {"binary": False},
                    "is_healthy": {"binary": False},
                    "disease": {"suggestions": []},
                }
            },
        )
    )
    client = httpx.AsyncClient(transport=transport)
    provider = KindwiseDiagnosisProvider(_settings(), client)

    with pytest.raises(DiagnosisRetakeError, match="PLANT_NOT_VISIBLE"):
        await provider.diagnose(_image(), "image/png", {})
    await client.aclose()


@pytest.mark.parametrize(
    ("status_code", "error_type", "failure_code"),
    [
        (400, DiagnosisPermanentError, "KINDWISE_IMAGE_REJECTED"),
        (401, DiagnosisPermanentError, "KINDWISE_AUTH_FAILED"),
        (429, DiagnosisTransientError, None),
        (503, DiagnosisTransientError, None),
    ],
)
async def test_kindwise_provider_maps_http_failures(
    status_code: int, error_type: type[Exception], failure_code: str | None
) -> None:
    client = httpx.AsyncClient(
        transport=httpx.MockTransport(lambda _request: httpx.Response(status_code))
    )
    provider = KindwiseDiagnosisProvider(_settings(), client)

    with pytest.raises(error_type) as error:
        await provider.diagnose(_image(), "image/png", {})
    if failure_code is not None:
        assert error.value.failure_code == failure_code
    await client.aclose()


async def test_kindwise_provider_rejects_invalid_response() -> None:
    client = httpx.AsyncClient(
        transport=httpx.MockTransport(lambda _request: httpx.Response(200, json={}))
    )
    provider = KindwiseDiagnosisProvider(_settings(), client)

    with pytest.raises(DiagnosisTransientError) as error:
        await provider.diagnose(_image(), "image/png", {})

    assert error.value.failure_code == "KINDWISE_INVALID_RESPONSE"
    await client.aclose()


async def test_kindwise_provider_requires_api_key_without_request() -> None:
    requested = False

    def handler(_request: httpx.Request) -> httpx.Response:
        nonlocal requested
        requested = True
        return httpx.Response(200)

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    provider = KindwiseDiagnosisProvider(Settings(_env_file=None), client)

    with pytest.raises(DiagnosisPermanentError) as error:
        await provider.diagnose(_image(), "image/png", {})

    assert error.value.failure_code == "KINDWISE_NOT_CONFIGURED"
    assert requested is False
    await client.aclose()
