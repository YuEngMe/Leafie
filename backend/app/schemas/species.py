from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.enums import (
    PlantCategory,
    SpeciesIdentificationStatus,
    WaterRecommendationSource,
)
from app.schemas.common import CursorPage


class RecommendedWater(BaseModel):
    min_ml: int = Field(gt=0)
    max_ml: int = Field(gt=0)
    source: WaterRecommendationSource


class SpeciesCandidate(BaseModel):
    reference_id: str
    display_name: str
    scientific_name: str | None = None
    category_suggestion: PlantCategory | None = None
    confidence: float | None = Field(default=None, ge=0, le=1)
    recommended_water: RecommendedWater | None = None


class SpeciesSearchResponse(CursorPage[SpeciesCandidate]):
    pass


class SpeciesIdentificationCreateRequest(BaseModel):
    media_file_id: UUID


class SpeciesIdentificationCreatedResponse(BaseModel):
    id: UUID
    status: SpeciesIdentificationStatus
    created_at: datetime


class SpeciesIdentificationResponse(BaseModel):
    id: UUID
    status: SpeciesIdentificationStatus
    current_candidate_index: int = 0
    candidates: list[SpeciesCandidate] = Field(default_factory=list)
    failure_code: str | None = None
    completed_at: datetime | None = None
