from fastapi import APIRouter

from app.api.v1.care import router as care_router
from app.api.v1.chat import router as chat_router
from app.api.v1.diagnoses import router as diagnoses_router
from app.api.v1.diaries import router as diaries_router
from app.api.v1.media import router as media_router
from app.api.v1.plants import router as plants_router
from app.api.v1.species import router as species_router
from app.api.v1.system import router as system_router
from app.api.v1.users import router as users_router

router = APIRouter()
router.include_router(system_router)
router.include_router(media_router)
router.include_router(users_router)
router.include_router(species_router)
router.include_router(plants_router)
router.include_router(diaries_router)
router.include_router(care_router)
router.include_router(chat_router)
router.include_router(diagnoses_router)
