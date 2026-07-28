from enum import StrEnum


class PlantCategory(StrEnum):
    FOLIAGE = "FOLIAGE"
    FLOWER = "FLOWER"
    SUCCULENT_CACTUS = "SUCCULENT_CACTUS"
    TREE = "TREE"
    HERB = "HERB"
    FRUIT = "FRUIT"
    VINE = "VINE"


class SpeciesSelectionMethod(StrEnum):
    SEARCH = "SEARCH"
    PHOTO = "PHOTO"


class SpeciesIdentificationStatus(StrEnum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class TaxonRank(StrEnum):
    SPECIES = "SPECIES"
    GENUS = "GENUS"
    FAMILY = "FAMILY"


class WaterRecommendationSource(StrEnum):
    SPECIES_GUIDE = "SPECIES_GUIDE"


class PersonalityType(StrEnum):
    OUTGOING = "OUTGOING"
    CHIC = "CHIC"
    CUTE = "CUTE"
    CRUSH = "CRUSH"
    INTROVERTED = "INTROVERTED"
    CHUNGCHEONG = "CHUNGCHEONG"


class ConditionLevel(StrEnum):
    VERY_BAD = "VERY_BAD"
    BAD = "BAD"
    NORMAL = "NORMAL"
    GOOD = "GOOD"
    VERY_GOOD = "VERY_GOOD"


class CareScheduleType(StrEnum):
    WATERING = "WATERING"
    REPOTTING = "REPOTTING"


class CareEventType(StrEnum):
    WATERING = "WATERING"
    REPOTTING = "REPOTTING"
    FERTILIZING = "FERTILIZING"
    PRUNING = "PRUNING"
    CUSTOM = "CUSTOM"


class CareEventStatus(StrEnum):
    SCHEDULED = "SCHEDULED"
    OVERDUE = "OVERDUE"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class MediaPurpose(StrEnum):
    USER_PROFILE = "USER_PROFILE"
    PLANT_PROFILE = "PLANT_PROFILE"
    SPECIES_IDENTIFICATION = "SPECIES_IDENTIFICATION"
    DIARY = "DIARY"
    DIAGNOSIS = "DIAGNOSIS"
    CHAT = "CHAT"


class MediaStatus(StrEnum):
    PENDING = "PENDING"
    READY = "READY"
    FAILED = "FAILED"
    DELETED = "DELETED"


class DiagnosisStatus(StrEnum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    NEEDS_RETAKE = "NEEDS_RETAKE"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


class DiagnosisCondition(StrEnum):
    HEALTHY = "HEALTHY"
    UNHEALTHY = "UNHEALTHY"
    UNCERTAIN = "UNCERTAIN"


class ChatRole(StrEnum):
    USER = "USER"
    ASSISTANT = "ASSISTANT"
    SYSTEM = "SYSTEM"


class AIMessageStatus(StrEnum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class ToolCallStatus(StrEnum):
    PENDING = "PENDING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class AIActionStatus(StrEnum):
    PENDING_CONFIRMATION = "PENDING_CONFIRMATION"
    EXECUTING = "EXECUTING"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"
    FAILED = "FAILED"


class BatchJobStatus(StrEnum):
    CREATED = "CREATED"
    SUBMITTED = "SUBMITTED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


class BatchItemStatus(StrEnum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class MonthlyReportStatus(StrEnum):
    PENDING = "PENDING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class DevicePlatform(StrEnum):
    IOS = "IOS"
    ANDROID = "ANDROID"


def enum_values(enum_type: type[StrEnum]) -> str:
    return ", ".join(f"'{item.value}'" for item in enum_type)
