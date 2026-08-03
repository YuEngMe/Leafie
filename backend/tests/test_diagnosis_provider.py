from decimal import Decimal
from io import BytesIO

import pytest
from PIL import Image
from pydantic import ValidationError

from app.integrations.diagnosis import (
    DiagnosisImageQualityResult,
    DiagnosisProviderResult,
    LocalDiagnosisImageQualityChecker,
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


def test_local_quality_check_can_leave_semantic_checks_unknown() -> None:
    result = DiagnosisImageQualityResult(
        acceptable=True,
        sharp_enough=True,
        brightness_acceptable=True,
    )

    assert result.plant_visible is None
    assert result.symptom_area_visible is None


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


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("observations", ["   "]),
        ("possible_causes", [{"name": "   "}]),
    ],
)
def test_provider_result_rejects_blank_display_text(field: str, value: list) -> None:
    payload = {
        "overall_condition": "UNCERTAIN",
        "condition_label": "추가 확인이 필요해요",
        "observations": ["잎 변색"],
        "possible_causes": [],
        "provider_name": "fake",
        "model_name": "fake-v1",
    }
    payload[field] = value

    with pytest.raises(ValidationError):
        DiagnosisProviderResult.model_validate(payload)


def _image_bytes(color: tuple[int, int, int], *, textured: bool = False) -> bytes:
    image = Image.new("RGB", (640, 640), color)
    if textured:
        pixels = image.load()
        for x in range(0, 640, 8):
            for y in range(640):
                pixels[x, y] = (20, 150, 40)
    output = BytesIO()
    image.save(output, format="JPEG")
    return output.getvalue()


async def test_local_quality_checker_accepts_clear_supported_image() -> None:
    result = await LocalDiagnosisImageQualityChecker().check(
        _image_bytes((120, 180, 100), textured=True),
        "image/jpeg",
    )

    assert result.acceptable is True
    assert result.retake_reason_code is None


async def test_local_quality_checker_rejects_dark_image() -> None:
    result = await LocalDiagnosisImageQualityChecker().check(
        _image_bytes((0, 0, 0)),
        "image/jpeg",
    )

    assert result.acceptable is False
    assert result.brightness_acceptable is False
    assert result.retake_reason_code == "IMAGE_TOO_DARK"


@pytest.mark.parametrize(
    ("image", "content_type", "reason_code"),
    [
        (_image_bytes((120, 180, 100), textured=True), "image/gif", "IMAGE_TYPE_UNSUPPORTED"),
        (Image.new("RGB", (256, 256), (120, 180, 100)), "image/jpeg", "IMAGE_TOO_SMALL"),
        (Image.new("RGB", (640, 640), (120, 180, 100)), "image/png", "IMAGE_BLURRY"),
        (b"not-an-image", "image/jpeg", "IMAGE_INVALID"),
    ],
)
async def test_local_quality_checker_rejects_invalid_inputs(
    image: bytes | Image.Image,
    content_type: str,
    reason_code: str,
) -> None:
    if isinstance(image, Image.Image):
        output = BytesIO()
        image.save(output, format="PNG")
        image = output.getvalue()

    result = await LocalDiagnosisImageQualityChecker().check(image, content_type)

    assert result.acceptable is False
    assert result.retake_reason_code == reason_code
