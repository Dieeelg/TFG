from fastapi import APIRouter
from datetime import datetime
from app.schemas.models import HealthResponse

router = APIRouter(
    prefix="/health",
    tags=["Sistema"]
)

@router.get("/", response_model=HealthResponse, summary="Estado da API")
def health():
    return {
        "status": "OK",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }