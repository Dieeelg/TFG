from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.dependencies import lifespan
from app.routers.extraccion import router as extraccion_router
from app.routers.estado import router as estado_router
from app.routers.notificar import router as notificar_router
from app.routers.centros import router as centros_router
from app.routers.preprocesamento import router as preprocesamento_router
import logging

# uvicorn app.main:app --reload

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
app = FastAPI(
    title="OCR SINTROM API (AZURE)",
    description="""API REST para a extracción de información de caracter clínico de informes
    de tratamento anticoagulante oral (Sintrom) mediante Azure Document Intelligence. A API devolve os datos 
    xa correctamente estruturados preparados para o seu uso na app de flutter.
    """,
    version="1.0.0",
    contact={
        "email": "diego.lgomez@udc.es",
    },
    lifespan=lifespan,

)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=[
        "X-Preprocesamento-Aplicado",
        "X-Preprocesamento-Metodo",
        "X-Preprocesamento-Motivo",
        "X-Preprocesamento-Angulo",
        "X-Preprocesamento-Confianza",
        "X-Preprocesamento-Dimensions-Orixinais",
        "X-Preprocesamento-Dimensions-Saida",
    ],
)

app.include_router(extraccion_router)
app.include_router(estado_router)
app.include_router(notificar_router)
app.include_router(centros_router)
app.include_router(preprocesamento_router)
