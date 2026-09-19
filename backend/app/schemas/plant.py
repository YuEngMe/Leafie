from datetime import date as Date
from datetime import datetime
from enum import StrEnum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.enums import (
    BodyType,
    CareEventSource,
    CareEventStatus,
    CareEventType,
    CareViewStatus,
    ColorType,
    ExpressionType,
    HairType,
    PersonalityType,
    PlantCategory,
    SpeciesSelectionMethod,
)


class PlantCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_registration_id: UUID
    nickname: str = Field(min_length=1, max_length=30)
    species_reference_id: str = Field(min_length=1, max_length=255)
    species_selection_method: SpeciesSelectionMethod
    species_identification_id: UUID | None = None
    primary_media_file_id: UUID | None = None
    started_on: Date
    place_name: str = Field(min_length=1, max_length=50)
    last_watered_on: Date
    last_repotted_on: Date | None = None
    personality_type: PersonalityType
    body_id: BodyType
    color_id: ColorType
    hair_id: HairType
    expression_id: ExpressionType

    @field_validator(
        "nickname",
        "species_reference_id",
        "place_name",
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


class PlantListItemResponse(BaseModel):
    id: UUID
    nickname: str
    species_reference_id: str
    species_display_name: str
    personality_type: PersonalityType
    body_id: BodyType
    color_id: str
    hair_id: str
    expression_id: ExpressionType
    primary_photo_url: str | None
    started_on: Date


class PlantListResponse(BaseModel):
    items: list[PlantListItemResponse]


class PlantDetailResponse(BaseModel):
    id: UUID
    nickname: str
    species_reference_id: str
    species_display_name: str
    category: PlantCategory
    scientific_name: str | None
    family_name: str | None
    flowering_period: str | None
    primary_photo_url: str | None
    started_on: Date
    place_name: str
    personality_type: PersonalityType
    body_id: BodyType
    color_id: str
    hair_id: str
    expression_id: ExpressionType
    created_at: datetime
    updated_at: datetime


class PlantUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nickname: str | None = Field(default=None, min_length=1, max_length=30)
    place_name: str | None = Field(default=None, min_length=1, max_length=50)
    personality_type: PersonalityType | None = None

    @field_validator("nickname", "place_name")
    @classmethod
    def strip_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        if not stripped:
            raise ValueError("공백만 입력할 수 없습니다.")
        return stripped

    @model_validator(mode="after")
    def require_change(self) -> "PlantUpdateRequest":
        if not self.model_fields_set:
            raise ValueError("수정할 값을 하나 이상 입력해 주세요.")
        if any(getattr(self, field) is None for field in self.model_fields_set):
            raise ValueError("수정 값에 null을 사용할 수 없습니다.")
        return self


class PlantAppearanceUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    body_id: BodyType | None = None
    color_id: ColorType | None = None
    hair_id: HairType | None = None
    expression_id: ExpressionType | None = None

    @model_validator(mode="after")
    def require_change(self) -> "PlantAppearanceUpdateRequest":
        if not self.model_fields_set:
            raise ValueError("수정할 값을 하나 이상 입력해 주세요.")
        if any(getattr(self, field) is None for field in self.model_fields_set):
            raise ValueError("수정 값에 null을 사용할 수 없습니다.")
        return self


class AgendaEventResponse(BaseModel):
    id: UUID
    care_type: CareEventType
    due_date: Date
    view_status: CareViewStatus
    source: CareEventSource
    completable: bool


class AgendaResponse(BaseModel):
    events: list[AgendaEventResponse]


class CalendarItemType(StrEnum):
    WATERING = "WATERING"
    REPOTTING = "REPOTTING"
    FERTILIZING = "FERTILIZING"


class CalendarItemResponse(BaseModel):
    id: UUID
    date: Date
    care_type: CalendarItemType
    status: CareEventStatus | None
    view_status: CareViewStatus | None
    source: CareEventSource | None
    completable: bool


class CalendarResponse(BaseModel):
    items: list[CalendarItemResponse]


class HomePlantResponse(BaseModel):
    id: UUID
    nickname: str
    started_on: Date
    days_together: int
    personality_type: PersonalityType
    body_id: BodyType
    color_id: str
    hair_id: str
    expression_id: ExpressionType
    primary_photo_url: str | None


class HomeBackgroundPhase(StrEnum):
    DAY = "DAY"
    NIGHT = "NIGHT"


class HomeDialogueKey(StrEnum):
    NORMAL = "NORMAL"
    WATERING_COMPLETED = "WATERING_COMPLETED"
    LIGHT_LOW = "LIGHT_LOW"
    LIGHT_HIGH = "LIGHT_HIGH"
    LIGHT_OPTIMAL = "LIGHT_OPTIMAL"
    SOIL_MOISTURE_LOW = "SOIL_MOISTURE_LOW"
    SOIL_MOISTURE_HIGH = "SOIL_MOISTURE_HIGH"
    DIARY_PROMPT = "DIARY_PROMPT"
    DIAGNOSIS_PROMPT = "DIAGNOSIS_PROMPT"
    LETTER_SENT = "LETTER_SENT"
    DIARY_RECEIVED = "DIARY_RECEIVED"


class HomeRoomResponse(BaseModel):
    background_phase: HomeBackgroundPhase
    dialogue_key: HomeDialogueKey
    dialogue: str | None


class HomeResponse(BaseModel):
    plant: HomePlantResponse | None
    room: HomeRoomResponse | None
    today_events: list[AgendaEventResponse]
    unread_letter_count: int
    unread_notification_count: int
