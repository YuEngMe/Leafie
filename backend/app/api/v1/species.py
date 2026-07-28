from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_user, get_database_session, get_job_queue
from app.core.request_context import create_request_id, get_request_id
from app.core.security import AuthenticatedUser
from app.integrations.queue import JobQueue
from app.schemas.queue import JobType, QueueJob
from app.schemas.species import (
    SpeciesIdentificationCreatedResponse,
    SpeciesIdentificationCreateRequest,
    SpeciesIdentificationResponse,
    SpeciesSearchResponse,
)
from app.services.species import SpeciesService, SQLAlchemySpeciesRepository

router = APIRouter(prefix="/plant-species", tags=["plant-species"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]
Queue = Annotated[JobQueue, Depends(get_job_queue)]


def build_service(session: AsyncSession) -> SpeciesService:
    return SpeciesService(SQLAlchemySpeciesRepository(session))


@router.get("/search", response_model=SpeciesSearchResponse)
async def search_species(
    current_user: CurrentUser,
    session: DatabaseSession,
    query: Annotated[str, Query()],
    cursor: Annotated[str | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> SpeciesSearchResponse:
    del current_user
    return await build_service(session).search(query, cursor, limit)


@router.post(
    "/identifications",
    response_model=SpeciesIdentificationCreatedResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def create_species_identification(
    request: SpeciesIdentificationCreateRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    queue: Queue,
) -> SpeciesIdentificationCreatedResponse:
    creation = await build_service(session).create_identification(
        current_user.id,
        request.media_file_id,
    )
    if creation.created:
        await queue.enqueue(
            QueueJob(
                job_type=JobType.SPECIES_IDENTIFICATION_RUN,
                resource_id=creation.response.id,
                trace_id=get_request_id() or create_request_id(),
            ),
            session=session,
        )
    return creation.response


@router.get(
    "/identifications/{identification_id}",
    response_model=SpeciesIdentificationResponse,
)
async def get_species_identification(
    identification_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> SpeciesIdentificationResponse:
    return await build_service(session).get_identification(current_user.id, identification_id)
