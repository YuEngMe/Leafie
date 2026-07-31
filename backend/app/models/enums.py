from enum import StrEnum


class AccountDeletionStatus(StrEnum):
    PENDING = "PENDING"
    FAILED = "FAILED"


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


class RepottingHistoryStatus(StrEnum):
    KNOWN = "KNOWN"
    NEVER = "NEVER"
    UNKNOWN = "UNKNOWN"


class SpeciesIdentificationStatus(StrEnum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class WaterRecommendationSource(StrEnum):
    SPECIES_GUIDE = "SPECIES_GUIDE"


class PersonalityType(StrEnum):
    OUTGOING = "OUTGOING"
    CHIC = "CHIC"
    CUTE = "CUTE"
    CRUSH = "CRUSH"
    INTROVERTED = "INTROVERTED"
    CHUNGCHEONG = "CHUNGCHEONG"


class PotType(StrEnum):
    TERRACOTTA = "TERRACOTTA"
    PLASTIC = "PLASTIC"
    GLASS = "GLASS"
    CERAMIC = "CERAMIC"
    HYDROPONIC = "HYDROPONIC"
    OTHER = "OTHER"


class Placement(StrEnum):
    VERANDA = "VERANDA"
    WINDOW = "WINDOW"
    LIVING_ROOM = "LIVING_ROOM"
    BEDROOM = "BEDROOM"
    DESK = "DESK"
    OTHER = "OTHER"


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
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class CareEventSource(StrEnum):
    AUTO_SCHEDULE = "AUTO_SCHEDULE"
    USER_CREATED = "USER_CREATED"
    AI_RECOMMENDED = "AI_RECOMMENDED"


class MediaPurpose(StrEnum):
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


class DevicePlatform(StrEnum):
    IOS = "IOS"
    ANDROID = "ANDROID"


def enum_values(enum_type: type[StrEnum]) -> str:
    return ", ".join(f"'{item.value}'" for item in enum_type)
