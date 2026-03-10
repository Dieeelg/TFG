from fastapi import FastAPI, HTTPException, APIRouter
from firebase_admin import messaging

from app.routers.extraccion import router
from app.schemas.models import NotificacionP2P, NotificacionResponse

router = APIRouter(
    prefix="/notificar",
    tags=["Comunicación P2P"],
)

@router.post("/enviar", response_model=NotificacionResponse)
async def enviar_notif(data: NotificacionP2P):
    try:
        message = messaging.Message(
            data = {
                "payload": data.payload,
                "tipo_aviso": data.tipo_aviso,
            },
            token= data.token_destino,
        )
        response = messaging.send(message)

        return NotificacionResponse(success=True, message_id=response)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao reenviar a notificación: {str(e)}"
        )