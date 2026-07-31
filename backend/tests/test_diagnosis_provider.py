from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.integrations.diagnosis import (
    DiagnosisImageQualityResult,
    DiagnosisProviderResult,
)


def test_provider_result_accepts_provider_probabilities() -> None:
    result = DiagnosisProviderResult.model_validate(
        {
            "overall_condition": "UNHEALTHY",
            "condition_label": "조금 관리가 필요해요",
            "observations": ["잎 끝 마름"],
            "possible_causes": [
                {"name": "물 부족", "confidence": 0.76},
                {"name": "습도 부족", "confidence": None},
            ],
            "provider_name": "fake",
            "model_name": "fake-v1",
            "response_id": "diagnosis_1",
            "latency_ms": 120,
            "estimated_cost": "0.010000",
            "cost_currency": "USD",
        }
    )

    assert result.possible_causes[0].confidence == 0.76
    assert result.possible_causes[1].confidence is None
    assert result.estimated_cost == Decimal("0.010000")


@pytest.mark.parametrize(
    "override",
    [
        {"possible_causes": [{"name": str(index)} for index in range(4)]},
        {"possible_causes": [{"name": "물 부족", "confidence": 1.1}]},
        {"estimated_cost": "0.01", "cost_currency": None},
        {"estimated_cost": None, "cost_currency": "USD"},
        {"unexpected": "value"},
    ],
)
def test_provider_result_rejects_invalid_normalized_data(override: dict) -> None:
    payload = {
        "overall_condition": "UNCERTAIN",
        "condition_label": "추가 확인이 필요해요",
        "observations": ["잎 변색"],
        "possible_causes": [],
        "provider_name": "fake",
        "model_name": "fake-v1",
    }
    payload.update(override)

    with pytest.raises(ValidationError):
        DiagnosisProviderResult.model_validate(payload)


def test_quality_result_requires_retake_reason_only_on_failure() -> None:
    passed = DiagnosisImageQualityResult(
        acceptable=True,
        plant_visible=True,
        sharp_enough=True,
        brightness_acceptable=True,
        symptom_area_visible=True,
    )
    failed = DiagnosisImageQualityResult(
        acceptable=False,
        plant_visible=True,
        sharp_enough=False,
        brightness_acceptable=True,
        symptom_area_visible=True,
        retake_reason_code="IMAGE_BLURRY",
    )

    assert passed.retake_reason_code is None
    assert failed.retake_reason_code == "IMAGE_BLURRY"


@pytest.mark.parametrize(
    "payload",
    [
        {"acceptable": False, "retake_reason_code": None},
        {"acceptable": True, "retake_reason_code": "IMAGE_BLURRY"},
    ],
)
def test_quality_result_rejects_inconsistent_retake_reason(payload: dict) -> None:
    with pytest.raises(ValidationError):
        DiagnosisImageQualityResult(
            plant_visible=True,
            sharp_enough=True,
            brightness_acceptable=True,
            symptom_area_visible=True,
            **payload,
        )
