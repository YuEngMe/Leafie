from decimal import Decimal
from typing import Protocol

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.enums import DiagnosisCondition


class DiagnosisCause(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    name: str = Field(min_length=1, max_length=200)
    confidence: float | None = Field(default=None, ge=0, le=1)


class DiagnosisProviderResult(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    overall_condition: DiagnosisCondition
    condition_label: str = Field(min_length=1, max_length=200)
    observations: list[str] = Field(min_length=1, max_length=10)
    possible_causes: list[DiagnosisCause] = Field(default_factory=list, max_length=3)
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
