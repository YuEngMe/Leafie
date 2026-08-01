import asyncio
from decimal import Decimal
from io import BytesIO
from typing import Annotated, Protocol

from PIL import Image, ImageFilter, ImageStat, UnidentifiedImageError
from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.models.enums import DiagnosisCondition

NonBlankText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]


class DiagnosisCause(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    name: Annotated[NonBlankText, StringConstraints(max_length=200)]
    confidence: float | None = Field(default=None, ge=0, le=1)


class DiagnosisProviderResult(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    overall_condition: DiagnosisCondition
    condition_label: str = Field(min_length=1, max_length=200)
    observations: list[Annotated[NonBlankText, StringConstraints(max_length=500)]] = Field(
        min_length=1,
        max_length=10,
    )
    possible_causes: list[DiagnosisCause] = Field(default_factory=list, max_length=3)
    care_suggestions: list[Annotated[NonBlankText, StringConstraints(max_length=1000)]] = Field(
        default_factory=list,
        max_length=10,
    )
    provider_name: str = Field(min_length=1, max_length=100)
    model_name: str = Field(min_length=1, max_length=200)
    response_id: str | None = Field(default=None, max_length=255)
    latency_ms: int | None = Field(default=None, ge=0)
    estimated_cost: Decimal | None = Field(default=None, ge=0)
    cost_currency: str | None = Field(default=None, pattern=r"^[A-Z]{3}$")

    @model_validator(mode="after")
    def validate_cost_metadata(self) -> "DiagnosisProviderResult":
        if (self.estimated_cost is None) != (self.cost_currency is None):
            raise ValueError("estimated_cost와 cost_currency는 함께 입력해야 합니다.")
        return self


class DiagnosisImageQualityResult(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    acceptable: bool
    plant_visible: bool
    sharp_enough: bool
    brightness_acceptable: bool
    symptom_area_visible: bool
    retake_reason_code: str | None = Field(
        default=None,
        max_length=100,
        pattern=r"^[A-Z][A-Z0-9_]*$",
    )

    @model_validator(mode="after")
    def validate_retake_reason(self) -> "DiagnosisImageQualityResult":
        if self.acceptable and self.retake_reason_code is not None:
            raise ValueError("통과한 사진에는 재촬영 사유를 지정할 수 없습니다.")
        if not self.acceptable and self.retake_reason_code is None:
            raise ValueError("재촬영이 필요한 사진에는 사유가 필요합니다.")
        return self


class DiagnosisProvider(Protocol):
    async def diagnose(
        self,
        image: bytes,
        content_type: str,
        context: dict,
    ) -> DiagnosisProviderResult: ...


class DiagnosisImageQualityChecker(Protocol):
    async def check(
        self,
        image: bytes,
        content_type: str,
    ) -> DiagnosisImageQualityResult: ...


class DiagnosisPermanentError(Exception):
    def __init__(self, failure_code: str) -> None:
        super().__init__(failure_code)
        self.failure_code = failure_code


class DiagnosisTransientError(Exception):
    pass


class DiagnosisRetakeError(Exception):
    def __init__(self, reason_code: str) -> None:
        super().__init__(reason_code)
        self.reason_code = reason_code


class LocalDiagnosisImageQualityChecker:
    def __init__(self, *, minimum_dimension: int = 512, sharpness_threshold: float = 10.0) -> None:
        self._minimum_dimension = minimum_dimension
        self._sharpness_threshold = sharpness_threshold

    async def check(
        self,
        image: bytes,
        content_type: str,
    ) -> DiagnosisImageQualityResult:
        return await asyncio.to_thread(self._check_sync, image, content_type)

    def _check_sync(
        self,
        image: bytes,
        content_type: str,
    ) -> DiagnosisImageQualityResult:
        try:
            with Image.open(BytesIO(image)) as source:
                source.verify()
            with Image.open(BytesIO(image)) as source:
                grayscale = source.convert("L")
        except (Image.DecompressionBombError, UnidentifiedImageError, OSError):
            return _rejected_quality("IMAGE_INVALID")

        if content_type not in {"image/jpeg", "image/png", "image/webp"}:
            return _rejected_quality("IMAGE_TYPE_UNSUPPORTED")
        if min(grayscale.size) < self._minimum_dimension:
            return _rejected_quality("IMAGE_TOO_SMALL")

        brightness = float(ImageStat.Stat(grayscale).mean[0])
        if brightness < 20:
            return _rejected_quality("IMAGE_TOO_DARK", brightness_acceptable=False)
        if brightness > 235:
            return _rejected_quality("IMAGE_TOO_BRIGHT", brightness_acceptable=False)

        margin = max(1, min(grayscale.size) // 100)
        inner = grayscale.crop(
            (margin, margin, grayscale.width - margin, grayscale.height - margin)
        )
        edges = inner.filter(ImageFilter.FIND_EDGES)
        edges = edges.crop((1, 1, edges.width - 1, edges.height - 1))
        sharpness = float(ImageStat.Stat(edges).var[0])
        if sharpness < self._sharpness_threshold:
            return _rejected_quality("IMAGE_BLURRY", sharp_enough=False)

        return DiagnosisImageQualityResult(
            acceptable=True,
            plant_visible=True,
            sharp_enough=True,
            brightness_acceptable=True,
            symptom_area_visible=True,
        )


def _rejected_quality(
    reason_code: str,
    *,
    sharp_enough: bool = True,
    brightness_acceptable: bool = True,
) -> DiagnosisImageQualityResult:
    return DiagnosisImageQualityResult(
        acceptable=False,
        plant_visible=True,
        sharp_enough=sharp_enough,
        brightness_acceptable=brightness_acceptable,
        symptom_area_visible=True,
        retake_reason_code=reason_code,
    )
