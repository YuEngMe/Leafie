from datetime import date as Date
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.enums import (
    PersonalityType,
    Placement,
    PotType,
    RepottingHistoryStatus,
    SpeciesSelectionMethod,
)


class RepottingHistory(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: RepottingHistoryStatus
    date: Date | None = None

    @model_validator(mode="after")
    def validate_date_for_status(self) -> "RepottingHistory":
        if self.status == RepottingHistoryStatus.KNOWN and self.date is None:
            raise ValueError("분갈이 날짜를 입력해 주세요.")
        if self.status != RepottingHistoryStatus.KNOWN and self.date is not None:
            raise ValueError("분갈이 날짜는 상태가 KNOWN일 때만 입력할 수 있습니다.")
        return self


class PlantCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nickname: str = Field(min_length=1, max_length=100)
    species_reference_id: str = Field(min_length=1, max_length=255)
    species_selection_method: SpeciesSelectionMethod
    species_identification_id: UUID | None = None
    primary_media_file_id: UUID | None = None
    started_on: Date
    place_name: str = Field(min_length=1, max_length=100)
    pot_type: PotType
    placement: Placement
    last_watered_on: Date
    repotting_history: RepottingHistory
    personality_type: PersonalityType
    color_id: str = Field(min_length=1, max_length=100)
    hair_id: str = Field(min_length=1, max_length=100)
    accessory_id: str = Field(min_length=1, max_length=100)

    @field_validator(
        "nickname",
        "species_reference_id",
        "place_name",
        "color_id",
        "hair_id",
        "accessory_id",
    )
    @classmethod
    def strip_nonblank_text(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("공백만 입력할 수 없습니다.")
        return stripped

    @model_validator(mode="after")
    def validate_species_selection_media(self) -> "PlantCreateRequest":
        if self.species_selection_method == SpeciesSelectionMethod.PHOTO:
            if self.species_identification_id is None or self.primary_media_file_id is None:
                raise ValueError("사진 인식 등록에는 인식 결과와 인식 사진이 필요합니다.")
        elif self.species_identification_id is not None or self.primary_media_file_id is not None:
            raise ValueError("검색 등록에는 식물 인식 결과나 대표 사진을 지정할 수 없습니다.")
        return self


class PlantCreateResponse(BaseModel):
    id: UUID
    created_at: datetime
