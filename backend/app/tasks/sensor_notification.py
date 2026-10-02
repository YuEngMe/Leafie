from datetime import UTC, datetime
from uuid import UUID, uuid5

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

from app.db.session import Database
from app.models.notification import Notification
from app.models.plant import Plant
from app.models.sensor import PlantSensorDevice, PlantSensorEvent
from app.models.user import UserProfile
from app.schemas.plant import HomeDialogueKey
from app.schemas.sensor import SensorLevel
from app.services.plant_management import home_dialogue
from app.services.sensor_assessment import SensorAssessmentService, local_zone

EVENT_DIALOGUES = {
    "SOIL_LOW": HomeDialogueKey.SOIL_MOISTURE_LOW,
    "SOIL_HIGH": HomeDialogueKey.SOIL_MOISTURE_HIGH,
    "LIGHT_LOW": HomeDialogueKey.LIGHT_LOW,
    "LIGHT_HIGH": HomeDialogueKey.LIGHT_HIGH,
}


class SensorNotificationCollectHandler:
    def __init__(self, database: Database):
        self.database = database

    async def __call__(self, job):
        del job
        await self.collect(datetime.now(UTC))

    async def collect(self, now: datetime) -> int:
        # Lock each user then plant, matching deletion/letter lock order; never revive deleted data.
        async with self.database.session_context() as session:
            plant_ids = list(
                await session.scalars(
                    select(Plant.id)
                    .join(PlantSensorDevice, PlantSensorDevice.plant_id == Plant.id)
                    .where(Plant.deleted_at.is_(None))
                    .order_by(Plant.id)
                )
            )
        created = 0
        for plant_id in plant_ids:
            async with self.database.session_context() as session:
                owner = await session.scalar(select(Plant.user_id).where(Plant.id == plant_id))
                profile = await session.scalar(
                    select(UserProfile).where(UserProfile.user_id == owner).with_for_update()
                )
                if profile is None or profile.deleted_at is not None:
                    continue
                plant = await session.scalar(
                    select(Plant)
                    .where(Plant.id == plant_id, Plant.deleted_at.is_(None))
                    .with_for_update()
                )
                if plant is None:
                    continue
                link = await session.scalar(
                    select(PlantSensorDevice)
                    .where(PlantSensorDevice.plant_id == plant.id)
                    .with_for_update()
                )
                if link is None:
                    continue
                assessment = await SensorAssessmentService(session).read(plant.id, now=now)
                if assessment.threshold_version is None:
                    continue
                today = now.astimezone(local_zone(profile.timezone)).date()
                for kind, metric in (("SOIL", assessment.soil), ("LIGHT", assessment.light)):
                    if metric.state not in (SensorLevel.LOW, SensorLevel.HIGH):
                        continue
                    event_type = f"{kind}_{metric.state}"
                    evaluation_date = metric.date if kind == "LIGHT" else today
                    event_id = uuid5(
                        UUID(str(plant.id)), f"{link.device_id}:{evaluation_date}:{event_type}"
                    )
                    inserted = await session.scalar(
                        insert(PlantSensorEvent)
                        .values(
                            id=event_id,
                            plant_id=plant.id,
                            device_id=link.device_id,
                            evaluation_date=evaluation_date,
                            type=event_type,
                            value=metric.value,
                            threshold_version=assessment.threshold_version,
                            occurred_at=now,
                        )
                        .on_conflict_do_nothing()
                        .returning(PlantSensorEvent.id)
                    )
                    if inserted is None:
                        continue
                    session.add(
                        Notification(
                            user_id=plant.user_id,
                            plant_id=plant.id,
                            type=f"SENSOR_{event_type}",
                            title=f"{plant.nickname}의 센서 상태를 확인해 주세요",
                            body=home_dialogue(plant.personality_type, EVENT_DIALOGUES[event_type]),
                            source_type="SENSOR_EVENT",
                            source_id=event_id,
                            created_at=now,
                        )
                    )
                    # In-app only: no FCM/APNs enqueue in the competition scope.
                    created += 1
        return created
