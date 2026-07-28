from fastapi import APIRouter

from app.api.v1.media import router as media_router
from app.api.v1.system import router as system_router
from app.api.v1.users import router as users_router

router = APIRouter()
router.include_router(system_router)
router.include_router(media_router)
router.include_router(users_router)
