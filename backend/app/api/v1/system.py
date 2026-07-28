from fastapi import APIRouter, Request, status
from fastapi.responses import JSONResponse

from app.core.errors import AppError
from app.schemas.common import HealthResponse

router = APIRouter(tags=["system"])


@router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    return HealthResponse(status="ok")


@router.get(
    "/ready",
    response_model=HealthResponse,
    responses={status.HTTP_503_SERVICE_UNAVAILABLE: {"description": "Not ready"}},
)
async def readiness_check(request: Request) -> HealthResponse | JSONResponse:
    try:
        await request.app.state.database.ping()
    except AppError as exc:
        return JSONResponse(
            status_code=exc.status_code,
            content={"status": "not_ready"},
        )
    return HealthResponse(status="ready")
