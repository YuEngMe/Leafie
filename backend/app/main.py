import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.api.router import api_router
from app.core.config import settings
from app.core.errors import register_exception_handlers
from app.core.logging import configure_logging
from app.core.request_context import (
    normalize_request_id,
    reset_request_id,
    set_request_id,
)
from app.core.security import SupabaseJWTVerifier
from app.db.session import Database
from app.integrations.openai_chat import OpenAIChatProvider
from app.integrations.queue import PgmqQueue
from app.integrations.storage import SupabaseStorageGateway

configure_logging(settings.log_level)
logger = logging.getLogger(__name__)


class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = normalize_request_id(request.headers.get("X-Request-ID"))
        token = set_request_id(request_id)
        try:
            response = await call_next(request)
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            reset_request_id(token)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    app.state.logger = logger
    app.state.database = Database(settings)
    app.state.queue = PgmqQueue(app.state.database, settings)
    app.state.jwt_verifier = SupabaseJWTVerifier(settings)
    app.state.storage = SupabaseStorageGateway(settings)
    app.state.openai_chat = OpenAIChatProvider(settings)
    yield
    await app.state.openai_chat.close()
    await app.state.storage.close()
    await app.state.jwt_verifier.close()
    await app.state.database.close()


def create_app() -> FastAPI:
    application = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        openapi_url=f"{settings.api_v1_prefix}/openapi.json",
        lifespan=lifespan,
    )
    application.add_middleware(RequestContextMiddleware)
    application.include_router(api_router, prefix=settings.api_v1_prefix)
    register_exception_handlers(application)
    return application


app = create_app()
