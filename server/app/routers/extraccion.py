import logging
from datetime import datetime
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.core.exceptions import HttpResponseError

from app.dependencies import get_azure_client
from app.schemas.models import AnalisisResponse, ErrorResponse, CabeceiraResponse, DoseDia, ItemHistorico, MetadatosResponse
from app.internal.logic import extraer_data, calcular_confianza_media, parsear_data, parse_dose_cell, \
    extraer_dose_semanal
from app.internal.constants import MODEL_ID, DOSE_COLS, INR_MIN_LOGICO, INR_MAX_LOGICO


router = APIRouter(
    prefix="/extraccion",
    tags=["Procesamento de Informes"]
)

@router.post("/",
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
                    logging.warning(f"INR fóra de rango detectado: {inr_valor}")
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