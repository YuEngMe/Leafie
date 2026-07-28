from collections.abc import AsyncIterator

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import Settings
from app.core.errors import AppError


class Database:
    def __init__(self, settings: Settings) -> None:
        self._database_url = settings.database_url
        self._engine: AsyncEngine | None = None
        self._session_factory: async_sessionmaker[AsyncSession] | None = None

    @property
    def is_configured(self) -> bool:
        return bool(self._database_url)

    @property
    def engine(self) -> AsyncEngine:
        self._initialize()
        assert self._engine is not None
        return self._engine

    async def session(self) -> AsyncIterator[AsyncSession]:
        self._initialize()
        assert self._session_factory is not None

        async with self._session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    async def ping(self) -> None:
        if not self.is_configured:
            raise AppError(
                code="DATABASE_NOT_CONFIGURED",
                message="데이터베이스 연결이 설정되지 않았습니다.",
                status_code=503,
            )
        try:
            async with self.engine.connect() as connection:
                await connection.execute(text("SELECT 1"))
        except (OSError, SQLAlchemyError) as exc:
            raise AppError(
                code="DATABASE_UNAVAILABLE",
                message="데이터베이스에 연결할 수 없습니다.",
                status_code=503,
            ) from exc

    async def close(self) -> None:
        if self._engine is not None:
            await self._engine.dispose()

    def _initialize(self) -> None:
        if not self._database_url:
            raise AppError(
                code="DATABASE_NOT_CONFIGURED",
                message="데이터베이스 연결이 설정되지 않았습니다.",
                status_code=503,
            )
        if self._engine is not None:
            return

        self._engine = create_async_engine(
            self._database_url,
            connect_args={"timeout": 5},
            pool_pre_ping=True,
        )
        self._session_factory = async_sessionmaker(
            bind=self._engine,
            class_=AsyncSession,
            expire_on_commit=False,
        )
