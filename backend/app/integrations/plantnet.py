import logging
import math
import re
from collections.abc import Mapping
from dataclasses import dataclass

import httpx

from app.core.config import Settings


class _PlantNetSecretFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = _redact_api_key(record.msg)
        if isinstance(record.args, tuple):
            record.args = tuple(_redact_api_key(value) for value in record.args)
        elif isinstance(record.args, dict):
            record.args = {key: _redact_api_key(value) for key, value in record.args.items()}
        return True


def _redact_api_key(value: object) -> object:
    if isinstance(value, httpx.URL) and "api-key" in value.params:
        return value.copy_set_param("api-key", "***")
    if isinstance(value, str):
        return re.sub(r"([?&]api-key=)[^&\s\"]+", r"\1***", value)
    return value


logging.getLogger("httpx").addFilter(_PlantNetSecretFilter())


@dataclass(frozen=True, slots=True)
class PlantNetCandidate:
    scientific_name: str
    common_names: tuple[str, ...]
    confidence: float
    gbif_id: int | None = None
    powo_id: str | None = None


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
            if not isinstance(payload, Mapping):
                raise TypeError("Pl@ntNet payload must be an object")
            raw_results = payload.get("results", [])
            if not isinstance(raw_results, list):
                raise TypeError("Pl@ntNet results must be a list")
            candidates = [_parse_candidate(result) for result in raw_results]
        except (KeyError, TypeError, ValueError) as exc:
            raise PlantNetPermanentError("PLANTNET_INVALID_RESPONSE") from exc

        candidates.sort(key=lambda candidate: candidate.confidence, reverse=True)
        return candidates[: self._result_limit]

    async def close(self) -> None:
        if self._owns_client:
            await self._client.aclose()


def _parse_candidate(result: object) -> PlantNetCandidate:
    if not isinstance(result, Mapping):
        raise TypeError("Pl@ntNet result must be an object")

    species = result.get("species")
    if not isinstance(species, Mapping):
        raise TypeError("Pl@ntNet species must be an object")

    scientific_name = species.get("scientificNameWithoutAuthor")
    if not isinstance(scientific_name, str) or not scientific_name.strip():
        raise ValueError("Pl@ntNet scientific name is missing")

    raw_common_names = species.get("commonNames") or []
    if not isinstance(raw_common_names, list) or not all(
        isinstance(name, str) for name in raw_common_names
    ):
        raise TypeError("Pl@ntNet common names must be a string list")

    confidence = float(result["score"])
    if not math.isfinite(confidence) or not 0 <= confidence <= 1:
        raise ValueError("Pl@ntNet score must be between 0 and 1")

    gbif = result.get("gbif") or {}
    powo = result.get("powo") or {}
    if not isinstance(gbif, Mapping) or not isinstance(powo, Mapping):
        raise TypeError("Pl@ntNet taxonomy references must be objects")

    return PlantNetCandidate(
        scientific_name=scientific_name.strip(),
        common_names=tuple(name.strip() for name in raw_common_names if name.strip()),
        confidence=confidence,
        gbif_id=_parse_optional_int(gbif.get("id")),
        powo_id=_parse_optional_string(powo.get("id")),
    )


def _parse_optional_int(value: object) -> int | None:
    if value is None:
        return None
    return int(value)


def _parse_optional_string(value: object) -> str | None:
    if value is None:
        return None
    parsed = str(value).strip()
    return parsed or None
