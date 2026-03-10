from pydantic import BaseModel, Field
from typing import List, Optional

class CabeceiraResponse(BaseModel):
    dataInforme: Optional[str] = Field(None,description="Data de emisión do informe en formato ISO (YYYY-MM-DD)", examples=["2025-01-14"])
    inr: Optional[str] = Field(None,description="Valor do INR no informe actual" ,examples=["2.5"])
    farmaco: Optional[str] = Field(None,description="Nome do fármaco prescrito", examples=["Sintrom 4 mg"])
    doseSemanal: Optional[str] = Field(None,description="Dose semanal prescrita" ,examples=["13,5 mg"])
    proximaVisita: Optional[str] = Field(None,description="Data do vindeiro control médico" ,examples=["05/04/2018"])
    centro: Optional[str] = Field(None,description="Nome do centro de saude ou hospital onde se realizará a visita" ,examples=["C.S. VIVEIRO"])

class DoseDia(BaseModel):
    data: str = Field(...,description="Data en formato ISO (YYYY-MM-DD)", examples=["2018-03-27"])
    dia: int = Field(...,description="Día do mes extraído da cela como un enteiro" ,examples=[27])
    dose: str|None = Field(...,description="Cantidade de fármaco (0, 1, 1/2, 1/4, 3/4 ...)", examples=["1/2"])
    accion: str = Field(...,description="Instrución para o paciente (TOMAR, NON TOMAR, CONTROL)" ,examples=["TOMAR"])
    eControl: bool = Field(...,description="Indica se o día require acudir a control médico ou é un dia de toma normal." ,examples=[False])
    diaSemanaTexto: str = Field(...,description="Día da semana en maiúsculas", examples=["MARTES"])

class MetadatosResponse(BaseModel):
    confianzaGlobal: float = Field(..., description="Media xeral de confianza do OCR", examples= [0.945])
    modelo: str = Field(None, description="Modelo entrenado de Document Intelligence empregado",examples=["M1"])

class ItemHistorico(BaseModel):
    data: Optional[str] = Field(None,description="Data da visita rexistrada no histórico en formato ISO" ,examples=["2018-03-20"])
    inr: Optional[str] = Field(None, description="Valor do INR nesa data histórica",examples=["4,5"])
    farmaco: Optional[str] = Field(None,description="Fármaco prescrito nesa data histórica" ,examples=["Sintrom 4 mg"])
    dose: Optional[str] = Field(None,description="Dose semanal nesa data histórica", examples=["13,5 mg"])
    apttInyectable: Optional[str] = Field(None,description="Tipo de heparina inxectable prescrita nesa data histórica" ,examples=["INHIXA 4.000"])
    doseInyectable: Optional[str] = Field(None, description="Dose de heparina inxectable prescrita nesa data histórica",examples=["4.000UJI"])
    proximaVisita: Optional[str] = Field(None, description="Data da próxima visita nesa data histórica",examples=["27/03/2018"])
    comentarios: Optional[str] = Field(None, description="Comentarios do facultativo nesa data histórica",examples=["HOY NO TOME SINTROM"])

class AnalisisResponse(BaseModel):
    cabeceira: CabeceiraResponse = Field(...,description="Datos xerais da visita actual.")
    calendario: List[DoseDia] = Field(...,description="Calendario con todas as tomas a realizar hasta o próximo control")
    historico: List[ItemHistorico] = Field(...,description="Rexistro das últimas visitas")
    metadatos: MetadatosResponse = Field(...,description="Información técnica sobre a análise do documento.")

class HealthResponse(BaseModel):
    status: str = Field(...,description="Estado actual da API" ,examples=["ok"])
    timestamp: str = Field(...,description="Data e hora actual do servizo en formato ISO" ,examples=["2026-01-31T01:08:29.331060"])
    version: str = Field(..., description="Versión actual da API", examples=["1.0.0"])

class ErrorResponse(BaseModel):
    detail: str= Field(..., description="Detalles do erro acontecido")

class NotificacionP2P(BaseModel):
    token_destino: str = Field(...,description="Token FMC do destino")
    payload: str = Field(...,description="Datos a enviar polo móbil de orixen cifrados ")
    tipo_aviso: str = Field(...,description="Tipo de mensaxe a enviar")

class NotificacionResponse(BaseModel):
    success: bool
    message_id: str