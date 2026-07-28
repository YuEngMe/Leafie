import re
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select, update

from app.core.errors import AppError
from app.db.session import Database
from app.integrations.plantnet import (
    PlantNetCandidate,
    PlantNetPermanentError,
    PlantNetProvider,
)
from app.integrations.storage import StorageGateway
from app.models.enums import SpeciesIdentificationStatus
from app.models.media import MediaFile, SpeciesIdentification
from app.models.plant import SpeciesCareGuide
from app.schemas.queue import QueueJob
from app.schemas.species import SpeciesCandidate
from app.services.species import guide_to_candidate
from app.tasks.base import PermanentTaskError


@dataclass(frozen=True, slots=True)
class IdentificationWork:
    object_path: str
    content_type: str


class SpeciesIdentificationRepository:
    def __init__(self, database: Database) -> None:
        self._database = database

    async def start(self, identification_id: UUID) -> IdentificationWork | None:
        async with self._database.session_context() as session:
            media_file_id = await session.scalar(
                update(SpeciesIdentification)
                .where(
                    SpeciesIdentification.id == identification_id,
                    SpeciesIdentification.status == SpeciesIdentificationStatus.PENDING,
                )
                .values(
                    status=SpeciesIdentificationStatus.PROCESSING.value,
                    provider="PLANTNET",
                    failure_code=None,
                )
                .returning(SpeciesIdentification.media_file_id)
            )
            if media_file_id is None:
                return None

            media_file = await session.get(MediaFile, media_file_id)
            if media_file is None:
                return None
            return IdentificationWork(
                object_path=media_file.object_path,
                content_type=media_file.content_type,
            )

    async def find_guides(
        self,
        candidates: list[PlantNetCandidate],
    ) -> dict[str, SpeciesCareGuide]:
        if not candidates:
            return {}
        async with self._database.session_context() as session:
            guides = (
                await session.scalars(
                    select(SpeciesCareGuide).where(SpeciesCareGuide.active.is_(True))
                )
            ).all()
        matches: dict[str, SpeciesCareGuide] = {}
        for guide in guides:
            if guide.gbif_id is not None:
                matches[f"gbif:{guide.gbif_id}"] = guide
            if guide.scientific_name is not None:
                matches[f"name:{guide.scientific_name.casefold()}"] = guide
            for alias in guide.aliases or []:
                matches[f"alias:{alias.casefold()}"] = guide
        return matches

    async def complete(
        self,
        identification_id: UUID,
        candidates: list[SpeciesCandidate],
    ) -> None:
        async with self._database.session_context() as session:
            identification = await session.get(SpeciesIdentification, identification_id)
            if identification is None or identification.status in {
                SpeciesIdentificationStatus.COMPLETED,
                SpeciesIdentificationStatus.FAILED,
            }:
                return
            identification.status = SpeciesIdentificationStatus.COMPLETED.value
            identification.candidates = [
                candidate.model_dump(mode="json", exclude_none=True) for candidate in candidates
            ]
            identification.failure_code = None
            identification.completed_at = datetime.now(UTC)

    async def fail(self, identification_id: UUID, failure_code: str) -> None:
        async with self._database.session_context() as session:
            identification = await session.get(SpeciesIdentification, identification_id)
            if identification is None or identification.status in {
                SpeciesIdentificationStatus.COMPLETED,
                SpeciesIdentificationStatus.FAILED,
            }:
                return
            identification.status = SpeciesIdentificationStatus.FAILED.value
            identification.candidates = []
            identification.failure_code = failure_code
            identification.completed_at = datetime.now(UTC)


class SpeciesIdentificationHandler:
    def __init__(
        self,
        repository: SpeciesIdentificationRepository,
        storage: StorageGateway,
        provider: PlantNetProvider,
    ) -> None:
        self._repository = repository
        self._storage = storage
        self._provider = provider

    async def __call__(self, job: QueueJob) -> None:
        work = await self._repository.start(job.resource_id)
        if work is None:
            return

        try:
            image = await self._storage.download_object(work.object_path)
            provider_candidates = await self._provider.identify(image, work.content_type)
        except PlantNetPermanentError as exc:
            await self._repository.fail(job.resource_id, exc.failure_code)
            raise PermanentTaskError(
                exc.failure_code,
                "식물 사진 인식을 완료할 수 없습니다.",
            ) from exc
        except AppError as exc:
            if exc.code == "MEDIA_UPLOAD_NOT_FOUND":
                await self._repository.fail(job.resource_id, exc.code)
                raise PermanentTaskError(exc.code, exc.message) from exc
            raise

        if not provider_candidates:
            await self._repository.fail(job.resource_id, "SPECIES_NO_CANDIDATES")
            return

        guides = await self._repository.find_guides(provider_candidates)
        candidates = [
            normalize_candidate(candidate, find_matching_guide(candidate, guides))
            for candidate in provider_candidates
        ]
        await self._repository.complete(job.resource_id, candidates)

    async def on_exhausted(self, job: QueueJob) -> None:
        await self._repository.fail(job.resource_id, "SPECIES_PROVIDER_UNAVAILABLE")


def normalize_candidate(
    candidate: PlantNetCandidate,
    guide: SpeciesCareGuide | None,
) -> SpeciesCandidate:
    if guide is not None:
        guide_candidate = guide_to_candidate(guide)
        return guide_candidate.model_copy(update={"confidence": candidate.confidence})

    display_name = (
        candidate.common_names[0] if candidate.common_names else candidate.scientific_name
    )
    reference_slug = re.sub(r"[^a-z0-9]+", "-", candidate.scientific_name.casefold()).strip("-")
    return SpeciesCandidate(
        reference_id=f"plantnet:{reference_slug}",
        display_name=display_name,
        scientific_name=candidate.scientific_name,
        confidence=candidate.confidence,
    )


def find_matching_guide(
    candidate: PlantNetCandidate,
    guides: dict[str, SpeciesCareGuide],
) -> SpeciesCareGuide | None:
    if candidate.gbif_id is not None:
        guide = guides.get(f"gbif:{candidate.gbif_id}")
        if guide is not None:
            return guide
    normalized_scientific_name = candidate.scientific_name.casefold()
    guide = guides.get(f"name:{normalized_scientific_name}") or guides.get(
        f"alias:{normalized_scientific_name}"
    )
    if guide is not None:
        return guide
    for common_name in candidate.common_names:
        guide = guides.get(f"alias:{common_name.casefold()}")
        if guide is not None:
            return guide
    return None
