import asyncio
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.db.session import Database
from app.integrations.plantnet import (
    PlantNetCandidate,
    PlantNetPermanentError,
    PlantNetProvider,
)
from app.integrations.storage import StorageGateway
from app.models.enums import MediaStatus, SpeciesIdentificationStatus
from app.models.media import MediaFile, SpeciesIdentification
from app.models.plant import SpeciesCareGuide
from app.models.user import UserProfile
from app.schemas.queue import QueueJob
from app.schemas.species import SpeciesCandidate
from app.services.species import guide_to_candidate
from app.tasks.ai_lease import claim, defer_if_active, owns
from app.tasks.base import PermanentTaskError


@dataclass(frozen=True, slots=True)
class IdentificationWork:
    object_path: str
    content_type: str
    token: UUID


class SpeciesIdentificationRepository:
    def __init__(
        self, database: Database, *, lease_seconds: int = 240, max_attempts: int = 5
    ) -> None:
        self._database = database
        self._lease_seconds = lease_seconds
        self._max_attempts = max_attempts

    async def _lock_source(
        self, session: AsyncSession, identification_id: UUID
    ) -> MediaFile | None:
        source = (
            await session.execute(
                select(SpeciesIdentification.user_id, SpeciesIdentification.media_file_id).where(
                    SpeciesIdentification.id == identification_id
                )
            )
        ).one_or_none()
        if source is None:
            return None
        profile = await session.scalar(
            select(UserProfile)
            .where(
                UserProfile.user_id == source.user_id,
                UserProfile.deleted_at.is_(None),
                UserProfile.deletion_status.is_(None),
            )
            .with_for_update()
        )
        if profile is None:
            return None
        return await session.scalar(
            select(MediaFile)
            .where(
                MediaFile.id == source.media_file_id,
                MediaFile.user_id == source.user_id,
                MediaFile.status == MediaStatus.READY,
                MediaFile.deleted_at.is_(None),
            )
            .with_for_update()
        )

    async def start(self, identification_id: UUID) -> IdentificationWork | None:
        async with self._database.session_context() as session:
            media_file = await self._lock_source(session, identification_id)
            if media_file is None:
                return None
            row = await session.scalar(
                select(SpeciesIdentification)
                .where(SpeciesIdentification.id == identification_id)
                .with_for_update()
            )
            if row is None:
                return None
            token = claim(
                row,
                lease_seconds=self._lease_seconds,
                max_attempts=self._max_attempts,
                failure_code="SPECIES_PROVIDER_UNAVAILABLE",
            )
            if token is None:
                return None
            row.provider = "PLANTNET"

            return IdentificationWork(
                object_path=media_file.object_path,
                content_type=media_file.content_type,
                token=token,
            )

    async def release_for_retry(self, identification_id: UUID, *, token: UUID) -> None:
        async with self._database.session_context() as session:
            row = await session.scalar(
                select(SpeciesIdentification)
                .where(SpeciesIdentification.id == identification_id)
                .with_for_update()
            )
            if not owns(row, token):
                return
            await session.execute(
                update(SpeciesIdentification)
                .where(
                    SpeciesIdentification.id == identification_id,
                    SpeciesIdentification.status == SpeciesIdentificationStatus.PROCESSING,
                    SpeciesIdentification.lease_token == token,
                )
                .values(
                    status=SpeciesIdentificationStatus.PENDING.value,
                    lease_token=None,
                    lease_until=None,
                    failure_code=None,
                )
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
        *,
        token: UUID,
    ) -> None:
        async with self._database.session_context() as session:
            if await self._lock_source(session, identification_id) is None:
                return
            identification = await session.scalar(
                select(SpeciesIdentification)
                .where(SpeciesIdentification.id == identification_id)
                .with_for_update()
            )
            if not owns(identification, token):
                return
            identification.lease_token = identification.lease_until = None
            identification.status = SpeciesIdentificationStatus.COMPLETED.value
            identification.candidates = [
                candidate.model_dump(mode="json", exclude_none=True) for candidate in candidates
            ]
            identification.failure_code = None
            identification.completed_at = datetime.now(UTC)

    async def fail(self, identification_id: UUID, failure_code: str, *, token: UUID) -> None:
        async with self._database.session_context() as session:
            if await self._lock_source(session, identification_id) is None:
                return
            identification = await session.scalar(
                select(SpeciesIdentification)
                .where(SpeciesIdentification.id == identification_id)
                .with_for_update()
            )
            if not owns(identification, token):
                return
            identification.lease_token = identification.lease_until = None
            identification.status = SpeciesIdentificationStatus.FAILED.value
            identification.candidates = []
            identification.failure_code = failure_code
            identification.completed_at = datetime.now(UTC)

    async def fail_after_retries(self, identification_id: UUID) -> None:
        async with self._database.session_context() as session:
            row = await session.scalar(
                select(SpeciesIdentification)
                .where(SpeciesIdentification.id == identification_id)
                .with_for_update()
            )
            if row is None or row.status not in {"PENDING", "PROCESSING"}:
                return
            defer_if_active(row)
            row.status = "FAILED"
            row.failure_code = "SPECIES_PROVIDER_UNAVAILABLE"
            row.lease_token = row.lease_until = None
            row.completed_at = datetime.now(UTC)


class SpeciesIdentificationHandler:
    manages_attempts = True

    def __init__(
        self,
        repository: SpeciesIdentificationRepository,
        storage: StorageGateway,
        provider: PlantNetProvider,
        *,
        external_call_timeout_seconds: float = 60,
    ) -> None:
        if external_call_timeout_seconds <= 0:
            raise ValueError("external_call_timeout_seconds must be positive")
        self._repository = repository
        self._storage = storage
        self._provider = provider
        self._timeout = external_call_timeout_seconds

    async def __call__(self, job: QueueJob) -> None:
        work = await self._repository.start(job.resource_id)
        if work is None:
            return

        try:
            image = await asyncio.wait_for(
                self._storage.download_object(work.object_path), timeout=self._timeout
            )
            provider_candidates = await asyncio.wait_for(
                self._provider.identify(image, work.content_type), timeout=self._timeout
            )
            if not provider_candidates:
                await self._repository.fail(
                    job.resource_id, "SPECIES_NO_CANDIDATES", token=work.token
                )
                return

            guides = await self._repository.find_guides(provider_candidates)
            candidates: list[SpeciesCandidate] = []
            seen_reference_ids: set[str] = set()
            for provider_candidate in provider_candidates:
                guide = find_matching_guide(provider_candidate, guides)
                if guide is None or guide.species_reference_id in seen_reference_ids:
                    continue
                seen_reference_ids.add(guide.species_reference_id)
                candidates.append(normalize_candidate(provider_candidate, guide))
            if not candidates:
                await self._repository.fail(
                    job.resource_id, "SPECIES_NO_CANDIDATES", token=work.token
                )
                return
            await self._repository.complete(job.resource_id, candidates, token=work.token)
        except PlantNetPermanentError as exc:
            await self._repository.fail(job.resource_id, exc.failure_code, token=work.token)
            raise PermanentTaskError(
                exc.failure_code,
                "식물 사진 인식을 완료할 수 없습니다.",
            ) from exc
        except AppError as exc:
            if exc.code == "MEDIA_UPLOAD_NOT_FOUND":
                await self._repository.fail(job.resource_id, exc.code, token=work.token)
                raise PermanentTaskError(exc.code, exc.message) from exc
            await self._repository.release_for_retry(job.resource_id, token=work.token)
            raise
        except Exception:
            await self._repository.release_for_retry(job.resource_id, token=work.token)
            raise

    async def on_exhausted(self, job: QueueJob) -> None:
        await self._repository.fail_after_retries(job.resource_id)


def normalize_candidate(
    candidate: PlantNetCandidate,
    guide: SpeciesCareGuide,
) -> SpeciesCandidate:
    guide_candidate = guide_to_candidate(guide)
    return guide_candidate.model_copy(update={"confidence": candidate.confidence})


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
