"""SQLAlchemy models."""

from app.models.care import CareEvent, CareSchedule
from app.models.diagnosis import Diagnosis
from app.models.letter import Letter
from app.models.media import MediaFile, SpeciesIdentification
from app.models.notification import Notification
from app.models.plant import (
    Plant,
    PlantDiary,
    PlantPersonalityChange,
    SpeciesCareGuide,
)
from app.models.sensor import PlantSensorDevice, SensorDevice, SensorDeviceClaim, SensorReading
from app.models.user import DeviceToken, UserProfile

__all__ = [
    "CareEvent",
    "CareSchedule",
    "DeviceToken",
    "Diagnosis",
    "Letter",
    "MediaFile",
    "Notification",
    "Plant",
    "PlantSensorDevice",
    "SensorDevice",
    "SensorDeviceClaim",
    "PlantDiary",
    "PlantPersonalityChange",
    "SensorReading",
    "SpeciesCareGuide",
    "SpeciesIdentification",
    "UserProfile",
]
