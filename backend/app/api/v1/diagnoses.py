from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_current_user,
    get_database_session,
    get_job_queue,
    get_storage_gateway,
)
from app.core.config import settings
from app.core.request_context import create_request_id, get_request_id
from app.core.security import AuthenticatedUser
from app.integrations.queue import JobQueue
from app.integrations.storage import StorageGateway
from app.schemas.diagnosis import (
    DiagnosisCreatedResponse,
    DiagnosisCreateRequest,
    DiagnosisDetailResponse,
    DiagnosisListResponse,
    DiagnosisStatusResponse,
)
from app.schemas.queue import JobType, QueueJob
from app.services.diagnosis import DiagnosisService, SQLAlchemyDiagnosisAPIRepository

router = APIRouter(tags=["diagnoses"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]
Queue = Annotated[JobQueue, Depends(get_job_queue)]
Storage = Annotated[StorageGateway, Depends(get_storage_gateway)]


def build_service(session: AsyncSession, storage: StorageGateway) -> DiagnosisService:
    return DiagnosisService(
        SQLAlchemyDiagnosisAPIRepository(session),
        storage,
        provider_configured=bool(settings.kindwise_api_key),
        download_url_expires_seconds=settings.media_download_url_expires_seconds,
    )


@router.post(
    "/plants/{plant_id}/diagnoses",
    response_model=DiagnosisCreatedResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def create_diagnosis(
    plant_id: UUID,
    request: DiagnosisCreateRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    queue: Queue,
    storage: Storage,
) -> DiagnosisCreatedResponse:
    response, created = await build_service(session, storage).create(
        current_user.id, plant_id, request
    )
    if created:
        await queue.enqueue(
            QueueJob(
                job_type=JobType.DIAGNOSIS_RUN,
                resource_id=response.diagnosis_id,
                trace_id=get_request_id() or create_request_id(),
            ),
            session=session,
        )
    return response


@router.get("/plants/{plant_id}/diagnoses", response_model=DiagnosisListResponse)
async def list_diagnoses(
    plant_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
    cursor: Annotated[str | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> DiagnosisListResponse:
    return await build_service(session, storage).list(current_user.id, plant_id, cursor, limit)


@router.get("/diagnoses/{diagnosis_id}", response_model=DiagnosisDetailResponse)
async def get_diagnosis(
    diagnosis_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> DiagnosisDetailResponse:
    return await build_service(session, storage).get(current_user.id, diagnosis_id)


@router.post(
    "/diagnoses/{diagnosis_id}/retry",
    response_model=DiagnosisStatusResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def retry_diagnosis(
    diagnosis_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    queue: Queue,
    storage: Storage,
) -> DiagnosisStatusResponse:
    response = await build_service(session, storage).retry(current_user.id, diagnosis_id)
    await queue.enqueue(
        QueueJob(
            job_type=JobType.DIAGNOSIS_RUN,
            resource_id=diagnosis_id,
            trace_id=get_request_id() or create_request_id(),
        ),
        session=session,
    )
    return response


@router.post("/diagnoses/{diagnosis_id}/cancel", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_diagnosis(
    diagnosis_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> Response:
    await build_service(session, storage).cancel(current_user.id, diagnosis_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
