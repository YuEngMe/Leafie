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


class DiaryWeather(StrEnum):
    SUNNY = "SUNNY"
    PARTLY_CLOUDY = "PARTLY_CLOUDY"
    CLOUDY = "CLOUDY"
    RAINY = "RAINY"
    SNOWY = "SNOWY"


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


class HairType(StrEnum):
    SUNFLOWER = "hair_sunflower"
    CHERRY_TOMATO = "hair_cherry_tomato"
    HYDRANGEA = "hair_hydrangea"
    POINTED_SUCCULENT = "hair_pointed_succulent"
    MONSTERA = "hair_monstera"
    FLOWER_CACTUS = "hair_flower_cactus"
    ROSETTE_SUCCULENT = "hair_rosette_succulent"
    SPROUT = "hair_sprout"
    DAISY = "hair_daisy"


class BodyType(StrEnum):
    CIRCLE = "body_circle"
    THUMB = "body_thumb"
    SQUARE = "body_square"


class CareScheduleType(StrEnum):
    WATERING = "WATERING"
    REPOTTING = "REPOTTING"


class CareEventType(StrEnum):
    WATERING = "WATERING"
    REPOTTING = "REPOTTING"
    FERTILIZING = "FERTILIZING"


class CareEventStatus(StrEnum):
    SCHEDULED = "SCHEDULED"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


class CareViewStatus(StrEnum):
    UPCOMING = "UPCOMING"
    TODAY = "TODAY"
    OVERDUE = "OVERDUE"
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


class DevicePlatform(StrEnum):
    IOS = "IOS"
    ANDROID = "ANDROID"


def enum_values(enum_type: type[StrEnum]) -> str:
    return ", ".join(f"'{item.value}'" for item in enum_type)
