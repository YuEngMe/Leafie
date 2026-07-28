from dataclasses import dataclass

import httpx

from app.core.config import Settings


@dataclass(frozen=True, slots=True)
class PlantNetCandidate:
    scientific_name: str
    common_names: tuple[str, ...]
    confidence: float


class PlantNetPermanentError(Exception):
    def __init__(self, failure_code: str) -> None:
        super().__init__(failure_code)
        self.failure_code = failure_code


class PlantNetTransientError(Exception):
    pass


class PlantNetProvider:
    def __init__(self, settings: Settings, client: httpx.AsyncClient | None = None) -> None:
        self._api_key = settings.plantnet_api_key
        self._base_url = settings.plantnet_base_url.rstrip("/")
        self._project = settings.plantnet_project
        self._language = settings.plantnet_language
        self._result_limit = settings.plantnet_result_limit
        self._owns_client = client is None
        self._client = client or httpx.AsyncClient(timeout=settings.plantnet_timeout_seconds)

    async def identify(self, image: bytes, content_type: str) -> list[PlantNetCandidate]:
        if not self._api_key:
            raise PlantNetPermanentError("PLANTNET_NOT_CONFIGURED")
        if content_type not in {"image/jpeg", "image/png"}:
            raise PlantNetPermanentError("SPECIES_IMAGE_TYPE_UNSUPPORTED")

        try:
            extension = "jpg" if content_type == "image/jpeg" else "png"
            response = await self._client.post(
                f"{self._base_url}/identify/{self._project}",
                params={
                    "api-key": self._api_key,
                    "lang": self._language,
                    "include-related-images": "false",
                    "no-reject": "false",
                    "nb-results": self._result_limit,
                },
                files={"images": (f"plant-image.{extension}", image, content_type)},
            )
        except httpx.HTTPError as exc:
            raise PlantNetTransientError("Pl@ntNet request failed") from exc

        if response.status_code == 429 or response.status_code >= 500:
            raise PlantNetTransientError(f"Pl@ntNet returned {response.status_code}")
        if response.status_code in {401, 403}:
            raise PlantNetPermanentError("PLANTNET_AUTH_FAILED")
        if response.status_code >= 400:
            raise PlantNetPermanentError("SPECIES_IMAGE_REJECTED")

        try:
            payload = response.json()
            raw_results = payload.get("results", [])
            candidates = [
                PlantNetCandidate(
                    scientific_name=result["species"]["scientificNameWithoutAuthor"],
                    common_names=tuple(result["species"].get("commonNames") or ()),
                    confidence=float(result["score"]),
                )
                for result in raw_results
            ]
        except (KeyError, TypeError, ValueError) as exc:
            raise PlantNetPermanentError("PLANTNET_INVALID_RESPONSE") from exc

        candidates.sort(key=lambda candidate: candidate.confidence, reverse=True)
        return candidates[: self._result_limit]

    async def close(self) -> None:
        if self._owns_client:
            await self._client.aclose()
