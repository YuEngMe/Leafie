import asyncio
import math
import time
from collections.abc import Mapping
from io import BytesIO

import httpx
from PIL import Image, UnidentifiedImageError

from app.core.config import Settings
from app.integrations.diagnosis import (
    DiagnosisCause,
    DiagnosisPermanentError,
    DiagnosisProviderResult,
    DiagnosisRetakeError,
    DiagnosisTransientError,
)
from app.models.enums import DiagnosisCondition


class KindwiseDiagnosisProvider:
    provider_name = "KINDWISE"

    def __init__(self, settings: Settings, client: httpx.AsyncClient | None = None) -> None:
        self._api_key = settings.kindwise_api_key
        self._base_url = settings.kindwise_base_url.rstrip("/")
        self._language = settings.kindwise_language
        self._owns_client = client is None
        self._client = client or httpx.AsyncClient(timeout=settings.kindwise_timeout_seconds)

    async def diagnose(
        self,
        image: bytes,
        content_type: str,
        context: dict,
    ) -> DiagnosisProviderResult:
        del context
        if not self._api_key:
            raise DiagnosisPermanentError("KINDWISE_NOT_CONFIGURED")

        normalized_image = await asyncio.to_thread(_normalize_image, image)
        started_at = time.perf_counter()
        try:
            response = await self._client.post(
                f"{self._base_url}/health_assessment",
                headers={"Api-Key": self._api_key},
                params={
                    "language": self._language,
                    "details": "local_name,description,treatment,is_harmful",
                },
                data={"disease_model": "full"},
                files={"images": ("plant.jpg", normalized_image, "image/jpeg")},
            )
        except httpx.HTTPError as exc:
            raise DiagnosisTransientError("Kindwise request failed") from exc

        if response.status_code in {401, 403}:
            raise DiagnosisPermanentError("KINDWISE_AUTH_FAILED")
        if response.status_code == 429 or response.status_code >= 500:
            raise DiagnosisTransientError(f"Kindwise returned {response.status_code}")
        if response.status_code >= 400:
            raise DiagnosisPermanentError("KINDWISE_IMAGE_REJECTED")

        try:
            payload = response.json()
            return _normalize_response(
                payload,
                latency_ms=round((time.perf_counter() - started_at) * 1000),
            )
        except DiagnosisRetakeError:
            raise
        except (KeyError, TypeError, ValueError) as exc:
            raise DiagnosisPermanentError("KINDWISE_INVALID_RESPONSE") from exc

    async def close(self) -> None:
        if self._owns_client:
            await self._client.aclose()


def _normalize_image(image: bytes) -> bytes:
    try:
        with Image.open(BytesIO(image)) as source:
            normalized = source.convert("RGB")
            normalized.thumbnail((1600, 1600))
            output = BytesIO()
            normalized.save(output, format="JPEG", quality=85, optimize=True)
            return output.getvalue()
    except (Image.DecompressionBombError, UnidentifiedImageError, OSError) as exc:
        raise DiagnosisPermanentError("KINDWISE_IMAGE_REJECTED") from exc


def _normalize_response(payload: object, *, latency_ms: int) -> DiagnosisProviderResult:
    if not isinstance(payload, Mapping):
        raise TypeError("Kindwise payload must be an object")
    result = _mapping(payload.get("result"), "result")
    is_plant = _mapping(result.get("is_plant"), "is_plant")
    if is_plant.get("binary") is False:
        raise DiagnosisRetakeError("PLANT_NOT_VISIBLE")

    is_healthy = _mapping(result.get("is_healthy"), "is_healthy")
    healthy = is_healthy.get("binary")
    if not isinstance(healthy, bool):
        raise TypeError("Kindwise is_healthy.binary must be boolean")

    disease = _mapping(result.get("disease"), "disease")
    raw_suggestions = disease.get("suggestions") or []
    if not isinstance(raw_suggestions, list):
        raise TypeError("Kindwise disease suggestions must be a list")
    suggestions = [_parse_suggestion(item) for item in raw_suggestions]
    suggestions.sort(key=lambda item: item[0].confidence or 0, reverse=True)

    causes = [cause for cause, _care, harmful in suggestions if harmful is not False][:3]
    care = _unique(
        item for _cause, items, harmful in suggestions if harmful is not False for item in items
    )
    if healthy:
        condition = DiagnosisCondition.HEALTHY
        label = "건강해 보여요"
        observations = ["사진에서 뚜렷한 건강 이상 징후가 감지되지 않았습니다."]
        causes = []
    else:
        condition = DiagnosisCondition.UNHEALTHY
        label = "조금 관리가 필요해요"
        observations = [f"{cause.name} 관련 징후가 감지되었습니다." for cause in causes]
        if not causes:
            condition = DiagnosisCondition.UNCERTAIN
            label = "추가 확인이 필요해요"
            observations = ["사진만으로 건강 이상 징후를 구분하기 어렵습니다."]

    response_id = payload.get("access_token")
    model_name = payload.get("model_version") or "plant.health-v3"
    if response_id is not None and not isinstance(response_id, str):
        raise TypeError("Kindwise access_token must be a string")
    if not isinstance(model_name, str):
        raise TypeError("Kindwise model_version must be a string")

    return DiagnosisProviderResult(
        overall_condition=condition,
        condition_label=label,
        observations=observations,
        possible_causes=causes,
        care_suggestions=care[:10],
        provider_name="KINDWISE",
        model_name=model_name,
        response_id=response_id,
        latency_ms=latency_ms,
    )


def _parse_suggestion(item: object) -> tuple[DiagnosisCause, list[str], bool | None]:
    suggestion = _mapping(item, "suggestion")
    probability = float(suggestion["probability"])
    if not math.isfinite(probability) or not 0 <= probability <= 1:
        raise ValueError("Kindwise probability must be between 0 and 1")
    details = _mapping(suggestion.get("details") or {}, "details")
    name = details.get("local_name") or suggestion.get("name")
    if not isinstance(name, str) or not name.strip():
        raise ValueError("Kindwise disease name is missing")
    harmful = details.get("is_harmful")
    if harmful is not None and not isinstance(harmful, bool):
        raise TypeError("Kindwise is_harmful must be boolean")
    care = _treatment_items(details.get("treatment"))
    return DiagnosisCause(name=name.strip(), confidence=probability), care, harmful


def _treatment_items(value: object) -> list[str]:
    if not isinstance(value, Mapping):
        return []
    items: list[str] = []
    for key in ("prevention", "biological"):
        content = value.get(key)
        if isinstance(content, str) and content.strip():
            items.append(content.strip()[:1000])
        elif isinstance(content, list):
            items.extend(
                item.strip()[:1000] for item in content if isinstance(item, str) and item.strip()
            )
    return items


def _mapping(value: object, name: str) -> Mapping:
    if not isinstance(value, Mapping):
        raise TypeError(f"Kindwise {name} must be an object")
    return value


def _unique(items) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result
