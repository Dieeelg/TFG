from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.dependencies import lifespan
from app.routers.extraccion import router as extraccion_router
from app.routers.system import router as system_router
from app.routers.notificar import router as notificar_router
import logging


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
)

app.include_router(extraccion_router)
app.include_router(system_router)
app.include_router(notificar_router)