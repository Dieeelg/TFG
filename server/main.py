import logging
import os
import re
from contextlib import asynccontextmanager
from datetime import datetime
from typing import List, Optional

from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.core.credentials import AzureKeyCredential
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from azure.core.exceptions import HttpResponseError

#=====================================
# CONFIGURACIÓN BÁSICA
#=====================================

# Endpoints de Azure ACORDARSE DE CAMBIAR A COLLELAS DO ENTORNO MELLOR
KEY_VAULT_URL = "https://almacen-tfg-sintrom.vault.azure.net/"
DOC_INTEL_ENDPOINT = "https://tfg-sintrom.cognitiveservices.azure.com/"

#Nome do segredo a recuperar
SECRET_NAME = "key-document-intelligence"

#Nome do modelo adestrado que imos a empregar
MODEL_ID = "M2"

#Columnas da táboa de dose
DOSE_COLS = ["LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SÁBADO", "DOMINGO"]

#Dicionario para mapear os meses de texto a número.
MESES_MAP ={
    "ENE": 1, "FEB": 2, "MAR": 3, "ABR": 4, "MAY": 5,
    "JUN": 6, "JUL": 7, "AGO": 8, "SEP": 9, "OCT": 10,
    "NOV": 11, "DIC": 12, "DEC": 12
}

# Definimos límites de seguridad para validación de INR
INR_MIN_LOGICO = 0.5
INR_MAX_LOGICO = 10.0

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

#=====================================
# MODELOS DE DATOS
#=====================================

class HealthResponse(BaseModel):
    status: str = Field(...,description="Estado actual da API" ,examples=["ok"])
    timestamp: str = Field(...,description="Data e hora actual do servizo en formato ISO" ,examples=["2026-01-31T01:08:29.331060"])
    version: str = Field(..., description="Versión actual da API", examples=["1.0.0"])

class ErrorResponse(BaseModel):
    detail: str= Field(..., description="Detalles do erro acontecido")

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

#=====================================
# FUNCIÓNS AUXILIARES
#=====================================

def calcular_confianza_media(document):
    """
    Percorre os campos extraídos e devolve a media de confianza.
    """
    confianzas = [field.confidence for field in document.fields.values() if field.confidence]
    if not confianzas:
        return 1.0 #REVISAR
    return sum(confianzas) / len(confianzas)

def extraer_dose_semanal(texto: str) -> Optional[str]:
    """
    Busca a dose semanal e devolve, limpando así o resto de cousas que non queremos
    Ex: 13,5 mg (1/2 día - DOM alternos 1/4) convertese en 13,5 mg.
    """
    if not texto:
        return None

    match = re.search(r"(\d+(?:[.,]\d+)?\s*mg)", texto, re.IGNORECASE)
    if match:
        return match.group(1)

    return texto

def extraer_data(texto: str) -> Optional[str]:
    """
    Busca un patrón DD/MM/YYYY ou YYYY-MM-DD nun texto e devólveo.
    Se non o atopa, devolve o texto orixinal.
    """
    if not texto:
        return None
    # Buscamos ambos formatos de data DD/MM/YYYY ou YYYY-MM-DD
    match = re.search(r"(\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2})", texto)
    if match:
        return match.group(1)
    return None

def parsear_data(data_str: str) -> Optional[datetime]:
    """
    Convirte un string DD/MM/YYYY ou YYYY-MM-DD nun obxecto datetime.
    """
    if not data_str:
        return None

    data = data_str.strip()
    try:
        if "-" in data:
            return datetime.strptime(data, "%Y-%m-%d")
        return datetime.strptime(data, "%d/%m/%Y")
    except ValueError:
        return None

def parse_dose_cell(raw_text: str, ano_base: int, mes_base: int,dt_proxima_visita: Optional[datetime] = None):
    """
     Función para transformar o contido dunha cela nun dicionario ordenado.
     Args:
         * raw_text (str): Texto que contén a data e a dose en formato texto.
            Exemplo:"21 1 ABR", "15 0 ABR NO TOMAR"  "19 1/4 ENE"
         * ano_base (int): Ano da visita.
         * mes_base (int): Mes da visita.
    Returns: Un dicionario con todos os campos separados:
     * "Data": data en formato YYYY-MM-DD
     * "Día": día do mes como un enteiro
     * "Dose": dose como texto ("1", "1/4", "0", ou None se é un control)
     * "Acción": "TOMAR", "NON TOMAR" ou "CONTROL"
     * "Control": True se a cela indica CONTROL, False noutro caso (Para poñer unha cor diferente en flutter)
     Devolve None se o texto non se pode interpretar correctamente.
    """
    if not raw_text:
            return None

    # Normaliza o texto
    texto = raw_text.upper().replace(",", ".").strip()

    """
    REVISAR O DE CONTROL PARA QUE SE NON COLLE O MES QUE O COLLA DO DE PROXIMA VISITA !!!!!
    Atopamos o seguinte erro, se en control non detectou o mes por que o leu mal ao ser 
    unha cela bastante escura, as veces confunde algo co fonde e detecta letras raras
    por iso debemos engadir algun mecanismo de consistencia para que setectou a data de 
    proxima visita se use esa para indicar o control, no caso de que si collese o de control
    se faga unha comprobación e comparación de ambas para garantizar a integridade das datas
    """

    #Atopar o mes (Maiúsculas) e quitámolo
    mes_match = re.search(r"(ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SEP|OCT|NOV|DIC|DEC)", texto)
    es_control = "CONTROL" in texto
    mes = None

    if mes_match:
        mes_str = mes_match.group(1)
        mes = MESES_MAP.get(mes_str, 0)
        texto_sen_mes = texto.replace(mes_str, "").strip()
    else:
        texto_sen_mes = texto
        if es_control and dt_proxima_visita:
            return {
                "data": dt_proxima_visita.date().isoformat(),
                "dia": dt_proxima_visita.day,
                "dose": None,
                "accion": "CONTROL",
                "control": True
            }

    if not mes: #REVISAR POR QUE SI NON ATOPA O MES DENTRO DUNHA DOSE DEVOLVE NONE e salta esa dose
        return None

    mes_str = mes_match.group(1)
    mes = MESES_MAP.get(mes_str, 0)



    #Buscamos os números da dose e do día
    # O que fai é devolver unha lista con todas as coincidencias: fraccións d+/d+ (dose) e enteiros d+ (día ou dose de 1)
    elementos = re.findall(r"\d+/\d+|\d+", texto_sen_mes)
    if not elementos:
        return None

    #Como a data é sempre o primeiro elemento e a dose o segundo
    try: #Se detectou algo que non é un enteiro (Coma unha dose 1/2, 1/4...) non a podemos coller como data
        dia = int(elementos[0])
    except ValueError:
        return None
    dose = str(elementos[1]) if len(elementos) > 1 else ""

    if "NO TOMAR" in texto:
        dose = "0"
        accion = "NON TOMAR"
    elif es_control:
        dose = None
        accion = "CONTROL"
    elif dose == "0": #REVISAR
        """
        Se se da o caso no que só atopa 0 pero non lee correctamente NO TOMAR pero si leu ben 0
        que poña a etiqueta NON TOMAR
        """
        accion = "NON TOMAR"
    else:
        accion = "TOMAR"

    #Por se toca cambio de ano na táboa
    ano = ano_base
    if mes_base == 12 and mes == 1:
        ano += 1
    try:
        data_iso = datetime(ano, mes, dia).date().isoformat()
    except ValueError:
        return None

    return {
        "data": data_iso,
        "dia": dia,
        "dose": dose,
        "accion": accion,
        "control": "CONTROL" in texto
    }

#=====================================
# CICLO DE VIDA DA APP
#=====================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
     Función para xestionar o ciclo de vida da app FastAPI.

     Encárgase de :
     * O arranque da app
     * A utenticación en Azure
     * Creación do cliente de Azure Document Intelligence
     * Deter a API

     Proceso de autenticación:
     1. Intentamos obter a clave de Axure Doc Intell desde a variable de
     contorna chamada DOC_INTEL_KEY.
     2. Se non se atopa dita variable, realizase a autenticación alternativa
     recuperando a clave de Azure Key Vault
     3. Se non se consigue ningunha das dúas a app detense cun erro.

    """
    logging.info("Iniciando conexión cos servizos de Azure...")

    #Intentamos coller a KEY directamente da variable de contorno
    api_key = os.getenv("DOC_INTEL_KEY")

    if not api_key:
        logging.info("Non se atopou DOC_INTEL_KEY, intentando conexión por Key Vault...")
        try:
            credential = DefaultAzureCredential(exclude_managed_identity_credential=True)
            kv_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
            secret = kv_client.get_secret(SECRET_NAME)
            api_key = secret.value
        except Exception as e:
            logging.error(f"ERRO CRÍTICO: Non se atopou ningunha forma de autenticación: {e}")
            raise e

    #Creamos o cliente de Document Intelligence coa clave
    try:
        client = DocumentIntelligenceClient(
            endpoint=DOC_INTEL_ENDPOINT,
            credential=AzureKeyCredential(api_key),
            api_version = "2024-11-30"
        )
        app.state.doc_intel_client = client
        logging.info("Cliente de Azure conectado e listo.")
    except Exception as e:
        logging.critical(f"Erro ao crear o cliente de Document Intelligence: {e}")
        raise e

    yield

    logging.info(f"API Detida correctamente")

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
def get_azure_client(request: Request) -> DocumentIntelligenceClient:
    client = request.app.state.doc_intel_client
    if not client:
        raise HTTPException(status_code=500, detail="Servizo Azure non dispoñible")
    return client

#=====================================
# ENDPOINTS DA API
#=====================================
@app.post("/extraccion/",
    response_description="Resultado da extracción estruturada do informe",
    response_model = AnalisisResponse,
    summary= "Iniciar a extracción de datos do informe de Sintrom",
    description="Recibe unha imaxe dun informe de tratamento anticoagulante oral (Sintrom), extrae os datos empregando Azure Document Intelligence e devolve a información de xeito estruturado",
     responses={
         400: {
            "model": ErrorResponse,
            "description": "Erro de validación do contido do informe ou datos non fiables",
            "content": {
                 "application/json": {
                   "example": {
                        "detail": "O documento non é lexible ou os datos detectados non son fiables"
                  }
                 }
          },
        },
         422: {
             "model": ErrorResponse,
             "description": "Erro de validación dos parámetros de entrada"
         },
         500: {
            "model": ErrorResponse,
            "description": "Erro interno do servidor",
            "content": {
                "application/json": {
                    "example": {
                        "detail": "Erro interno do servidor ao procesar a imaxe"
                    }
                }
            },
        },
         502:{
            "model": ErrorResponse,
            "description": "Erro ao comunicarse co servizo externo de Azure Document Intelligence",
            "content": {
                 "application/json": {
                      "example": {
                          "detail": "Erro ao comunicarse co servizo de anlise de documentos de Azure"
                     }
                 }
            }
        },

    },
    tags=["Procesamento de Informes"]
)
async def iniciar_extraccion(file: UploadFile = File(... ,description="Imaxe ou PDF do informe de Sintrom (JPEG, PNG, HEIC ou PDF)"),
                             client: DocumentIntelligenceClient = Depends(get_azure_client) ):
    """
    Endpoint que recibe unha foto dun informe de sintrom, extrae os datos con Azure
    e devolve un JSON coa información relevante limpa para a nosa app.
    """

    if file.content_type not in ["image/jpeg", "image/png", "image/heic", "application/pdf", "application/octet-stream"]:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo de ficheiro non soportado: {file.content_type}"
        )

    try:
        #Leemos o ficheiro que envoiu o usurio
        image_content = await file.read()
        logging.info(f"iniciando o análise da imaxe")

        #Chamamos ao modelo de Azure
        ocr_operation = client.begin_analyze_document(
            model_id=MODEL_ID,
            body=image_content,
            content_type="application/octet-stream"
        )

        result = ocr_operation.result()

        if not result.documents:
            raise HTTPException(
                status_code=400,
                detail="Non se detectou un documento válido na imaxe"
            )

        document = result.documents[0]
        confianza = calcular_confianza_media(document)

        if confianza < 0.6:  # Se a confianza é menos do 60%
            raise HTTPException(
                status_code=400,
                detail=f"O documento non é lexible. Por favor, faga unha foto con mellor luz e enfoque"
            )

        #Limpamos a data e transformamola en obxecto datetime
        campo_data_raw = document.fields.get("fecha visita").content if document.fields.get("fecha visita") else ""
        data_informe_limpa = extraer_data(campo_data_raw)
        dt_informe = parsear_data(data_informe_limpa)

        # Collemos o ano  se o hai e se non asumimos ano actual
        ano_actual = dt_informe.year if dt_informe else datetime.today().year
        # Collemos o mes  se o hai e se non asumimos mes actual
        mes_actual = dt_informe.month if dt_informe else datetime.today().month
        # Collemos a data do informe se o hai e se non asumimos dia actual
        dt_informe = dt_informe or datetime.now()

        def get_text(field_name): #Funcion axuliar para extraer os datos de forma segura
            field = document.fields.get(field_name)
            return field.content if field else None

        # Validación conoloxica
        prox_visit_raw = get_text("prox visit")
        prox_visit_limpa = extraer_data(prox_visit_raw)
        dt_prox = parsear_data(prox_visit_limpa)

        if dt_prox:
            if dt_prox.date() < dt_informe.date():
                logging.warning(
                    f"A data da proxima visita ({dt_prox.date()}) é anterior á data do informe {dt_informe.date()}.")
                raise HTTPException(
                    status_code=400,
                    detail="A data de proxima visita parece incorrecta"
                )

        # Táboa dose
        lista_doses = []
        campo_dose = document.fields.get("DOSE")

        #REVISAAR: Hai veces que azure devolve a confianza e utras non a devovle, observamos que ainda que non a devolva
        # os campos da táboa que da son todos correctos. Podemos facer que cando non detecte confianza que siga adiante e só no
        #caso de que haxa confianza e esta sexa baixa salte o erro 400

        """# No casso de que azure non teña unha boa confianza nos resultados da táboa lanzamos un erro
        if campo_dose and campo_dose.confidence:
            if campo_dose.confidence < 0.8:
                logging.warning(f"Confianza da táboa de doses menor que 0.8 ({campo_dose.confidence})")
                raise HTTPException(
                    status_code=400,
                    detail = "Non podemos asegurar a precisión da táboa de doses. Por favor, saque unha foto máis nítida ou centrada."
                )
        """
        if campo_dose and campo_dose.value_array:
            # Percorremos cada fila da táboa
            for fila in campo_dose.value_array:
                if fila.value_object:
                    # Percorremos cada columna (LUNES, MARTES...)
                    for dia_sem in DOSE_COLS:
                        celda = fila.value_object.get(dia_sem)
                        if celda:
                            datos = parse_dose_cell(celda.content, ano_actual, mes_actual,dt_prox)
                            if datos:
                                if datos["control"] and dt_prox :
                                    data_celda = parsear_data(datos["data"])
                                    if data_celda.date != dt_prox.date():
                                        logging.warning("A data do control extraída da táboa é errónea, collendo a de próxima visita.")
                                        # Poñemos a data de próxima visita
                                        datos["data"] = dt_prox.date().isoformat()
                                        datos["dia"] = dt_prox.day

                                datos["diaSemanaTexto"] = dia_sem
                                lista_doses.append(datos)
        if not lista_doses:
            raise HTTPException(
                status_code=400,
                detail=f"Táboa de dose non atopada, asegúrese de que se vexa enteira na imaxe."
            )

        #Ordenamos por orde cronolóxico para faiclitar o seu uso
        lista_doses.sort(key=lambda x: x['data'])

        lista_ruv = []

        mapa_columnas = {
            "fecha": "data",
            "inr": "inr",
            "fármaco avk": "farmaco",
            "farmaco avk": "farmaco",
            "dosis": "dose",
            "aptt inyectable": "apttInyectable",
            "aptt": "apttInyectable",
            "dosis iny": "doseInyectable",
            "inyectable": "doseInyectable",
            "próx. visita": "proximaVisita",
            "próx visita": "proximaVisita",
            "prox visita": "proximaVisita",
            "comentarios": "comentarios"
        }

        campo_ruv = document.fields.get("RUV")

        if campo_ruv and campo_ruv.value_array:
            for fila in campo_ruv.value_array:
                if fila.value_object:
                    datos_fila = {}

                    for key_azure, val_azure in fila.value_object.items():
                        if not val_azure: continue

                        clave_limpa = key_azure.lower().strip()

                        if clave_limpa in mapa_columnas:
                            campo_pydantic = mapa_columnas[clave_limpa]
                            datos_fila[campo_pydantic] = val_azure.content

                    # Se atopamos polo menos a data ou o INR, gardamos a fila
                    if "data" in datos_fila or "inr" in datos_fila:
                        lista_ruv.append(ItemHistorico(**datos_fila))

        #Validación do INR
        inr_texto = get_text("inr")
        inr_field = document.fields.get("inr")
        if inr_texto:
            try:
                inr_limpo = inr_texto.replace(",",".").strip()
                inr_valor = float(inr_limpo)

                if inr_valor < INR_MIN_LOGICO or inr_valor > INR_MAX_LOGICO:
                    logging.warning(f"INR fóra de ranfo detectado: {inr_valor}")
                    raise HTTPException(
                        status_code=400,
                        detail=f"O valor de INR detectado {inr_valor} non parece correcto. Por favor, saque unha foto máis nítida ou centrada."
                    )
                if inr_field.confidence < 0.8:
                    logging.warning(f"Confianza do INR menor que 0.8 ({inr_field.confidence})")
                    raise HTTPException(
                        status_code=400,
                        detail="Non podemos asegurar a precisión do valor do INR. Por favor, saque unha foto máis nítida ou centrada."
                    )
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="Erro co INR. Revisa que sexa lexible na imaxe"
                )

        return AnalisisResponse(
        cabeceira=CabeceiraResponse(
                dataInforme=data_informe_limpa,
                inr=get_text("inr"),
                farmaco=get_text("farmaco oral"),
                doseSemanal=extraer_dose_semanal(get_text("dosis semanal")),
                proximaVisita=prox_visit_limpa,
                centro=get_text("centro visita")
            ),

            calendario=[
                DoseDia(
                    data=d["data"],
                    dia=d["dia"],
                    dose=d["dose"],
                    accion=d["accion"],
                    eControl=d["control"],
                    diaSemanaTexto=d["diaSemanaTexto"]
                ) for d in lista_doses
            ],
            historico=lista_ruv,
            metadatos=MetadatosResponse(
                confianzaGlobal=confianza,
                modelo=MODEL_ID
            )
        )
    except HttpResponseError: #Para diferenciar os erros do servizo de azure dos nosos internos
        raise HTTPException(
            status_code=502,
            detail="Erro ao comunicarse co servizo de análise de documentos de Azure"
        )

    except HTTPException as erro:
        raise erro

    except Exception as e:
        logging.error(f"Erro inesperado procesando imaxe: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Erro interno do servidor: {str(e)}"
        )

@app.get("/health",
         summary="Estado da API",
         response_model=HealthResponse,
         tags=["Sistema"]
         )
def health():
    return {
        "status": "OK",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }