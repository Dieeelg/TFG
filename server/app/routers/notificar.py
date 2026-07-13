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
        textos = {
            "TOMA_CONFIRMADA": ("Toma confirmada", "A persoa supervisada confirmou a toma."),
            "NOVO_INFORME": ("Novo informe", "Actualizouse a folla de tratamento."),
            "TOMA_PENDENTE": ("Hora da toma", "Hai unha toma pendente de confirmar."),
            "TOMA_ESQUECIDA": ("Toma sen confirmar", "A toma segue sen confirmarse."),
        }
        titulo_corpo = textos.get(data.tipo_aviso)
        message = messaging.Message(
            data = {
                "payload": data.payload,
                "tipo_aviso": data.tipo_aviso,
            },
            notification=(
                messaging.Notification(title=titulo_corpo[0], body=titulo_corpo[1])
                if titulo_corpo else None
            ),
            token= data.token_destino,
        )
        response = messaging.send(message)

        return NotificacionResponse(success=True, message_id=response)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao reenviar a notificación: {str(e)}"
        )
