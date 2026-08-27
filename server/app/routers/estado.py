from fastapi import APIRouter
from datetime import datetime
from app.schemas.models import EstadoResponse

router = APIRouter(
    prefix="/estado",
    tags=["Sistema"]
)

@router.get("/", response_model=EstadoResponse, summary="Estado da API")
def comprobar_estado():
    return {
        "status": "OK",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }