import re
from datetime import datetime
from typing import Optional, List
from app.internal.constants import MESES_MAP


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

    #Atopar o mes e quitámolo
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

    """
    Investigar sobre unha medida de seguridade para os meses das doses, ter en conta os dias que ten cada mes, asi podemos saber cando toca cambiar de mes e no caso de que non
    se lea ben poder poñelo correctamente. Ou no caso de que a data da dose seguinte non se consiga ler e sexa menor a data de proxima visita pois que se rechee coa data correspondete
    (SO NO CASO DE QUE SI TEÑAMOS UNHA DOSE
    
    
    
    
    )
    """

    if not mes: #REVISAR
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