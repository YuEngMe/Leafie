from datetime import date as Date
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
from app.schemas.plant import (
    AgendaResponse,
    CalendarResponse,
    HomeResponse,
    PlantAppearanceUpdateRequest,
    PlantCreateRequest,
    PlantCreateResponse,
    PlantDetailResponse,
    PlantListResponse,
    PlantUpdateRequest,
)
from app.schemas.queue import JobType, QueueJob
from app.services.plant import PlantRegistrationService, SQLAlchemyPlantRegistrationRepository
from app.services.plant_management import (
    PlantManagementService,
    SQLAlchemyPlantManagementRepository,
)

router = APIRouter(prefix="/plants", tags=["plants"])
home_router = APIRouter(tags=["home"])

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]
CurrentUser = Annotated[AuthenticatedUser, Depends(get_current_user)]
Storage = Annotated[StorageGateway, Depends(get_storage_gateway)]
Queue = Annotated[JobQueue, Depends(get_job_queue)]


def build_service(session: AsyncSession) -> PlantRegistrationService:
    return PlantRegistrationService(SQLAlchemyPlantRegistrationRepository(session))


def build_management_service(
    session: AsyncSession, storage: StorageGateway
) -> PlantManagementService:
    return PlantManagementService(
        SQLAlchemyPlantManagementRepository(session),
        storage,
        download_url_expires_seconds=settings.media_download_url_expires_seconds,
    )


@router.post("", response_model=PlantCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_plant(
    request: PlantCreateRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> PlantCreateResponse:
    return await build_service(session).create_plant(current_user.id, request)


@router.get("", response_model=PlantListResponse)
async def list_plants(
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> PlantListResponse:
    return await build_management_service(session, storage).list_plants(current_user.id)


@router.get("/{plant_id}", response_model=PlantDetailResponse)
async def get_plant(
    plant_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> PlantDetailResponse:
    return await build_management_service(session, storage).get_plant(current_user.id, plant_id)


@router.patch("/{plant_id}", response_model=PlantDetailResponse)
async def update_plant(
    plant_id: UUID,
    request: PlantUpdateRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> PlantDetailResponse:
    return await build_management_service(session, storage).update_plant(
        current_user.id, plant_id, request
    )


@router.patch("/{plant_id}/appearance", response_model=PlantDetailResponse)
async def update_plant_appearance(
    plant_id: UUID,
    request: PlantAppearanceUpdateRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
) -> PlantDetailResponse:
    return await build_management_service(session, storage).update_appearance(
        current_user.id, plant_id, request
    )


@router.get("/{plant_id}/agenda", response_model=AgendaResponse)
async def get_plant_agenda(
    plant_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
    scope: Annotated[str, Query(pattern="^active$")] = "active",
) -> AgendaResponse:
    del scope
    return await build_management_service(session, storage).list_agenda(current_user.id, plant_id)


@router.get("/{plant_id}/calendar", response_model=CalendarResponse)
async def get_plant_calendar(
    plant_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
    date_from: Annotated[Date, Query(alias="from")],
    date_to: Annotated[Date, Query(alias="to")],
    types: str | None = None,
) -> CalendarResponse:
    return await build_management_service(session, storage).list_calendar(
        current_user.id, plant_id, date_from, date_to, types
    )


@router.delete("/{plant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_plant(
    plant_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
    queue: Queue,
) -> Response:
    result = await build_management_service(session, storage).delete_plant(
        current_user.id, plant_id
    )
    if result.enqueue_cleanup:
        await queue.enqueue(
            QueueJob(
                job_type=JobType.PLANT_DELETE,
                resource_id=plant_id,
                trace_id=get_request_id() or create_request_id(),
            ),
            session=session,
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@home_router.get("/home", response_model=HomeResponse)
async def get_home(
    current_user: CurrentUser,
    session: DatabaseSession,
    storage: Storage,
    plant_id: UUID | None = None,
) -> HomeResponse:
    return await build_management_service(session, storage).get_home(current_user.id, plant_id)
