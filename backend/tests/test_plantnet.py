import httpx
import pytest

from app.core.config import Settings
from app.integrations.plantnet import (
    PlantNetPermanentError,
    PlantNetProvider,
    PlantNetTransientError,
)


def make_provider(handler, **settings_overrides: object) -> PlantNetProvider:
    settings = Settings(
        _env_file=None,
        plantnet_api_key="test-key",
        **settings_overrides,
    )
    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    return PlantNetProvider(settings, client)


async def test_plantnet_normalizes_and_sorts_candidates() -> None:
    async def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["api-key"] == "test-key"
        assert request.url.params["lang"] == "ko"
        assert request.headers["content-type"].startswith("multipart/form-data")
        return httpx.Response(
            200,
            json={
                "results": [
                    {
                        "score": 0.2,
                        "species": {
                            "scientificNameWithoutAuthor": "Ocimum tenuiflorum",
                            "commonNames": ["홀리 바질"],
                        },
                    },
                    {
                        "score": 0.91,
                        "species": {
                            "scientificNameWithoutAuthor": "Ocimum basilicum",
                            "commonNames": ["바질"],
                        },
                    },
                ]
            },
        )

    provider = make_provider(handler)
    candidates = await provider.identify(b"\xff\xd8\xffimage", "image/jpeg")

    assert [candidate.scientific_name for candidate in candidates] == [
        "Ocimum basilicum",
        "Ocimum tenuiflorum",
    ]
    assert candidates[0].confidence == 0.91


@pytest.mark.parametrize("status_code", [429, 500, 503])
async def test_plantnet_retries_transient_statuses(status_code: int) -> None:
    async def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(status_code)

    with pytest.raises(PlantNetTransientError):
        await make_provider(handler).identify(b"\x89PNG\r\n\x1a\n", "image/png")


async def test_plantnet_reports_missing_configuration() -> None:
    settings = Settings(_env_file=None, plantnet_api_key=None)
    client = httpx.AsyncClient()
    provider = PlantNetProvider(settings, client)

    with pytest.raises(PlantNetPermanentError) as error:
        await provider.identify(b"\xff\xd8\xffimage", "image/jpeg")

    assert error.value.failure_code == "PLANTNET_NOT_CONFIGURED"
    await client.aclose()
