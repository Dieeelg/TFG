import html
import re
import unicodedata
import xml.etree.ElementTree as ET
from difflib import SequenceMatcher
from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/centros", tags=["Centros sanitarios"])

KML_PATH = Path(__file__).resolve().parent.parent / "data" / "centros_sanitarios.kml"
KML_NS = {"kml": "http://www.opengis.net/kml/2.2"}


def _normalizar(texto: str) -> str:
    texto = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    texto = texto.upper()
    texto = re.sub(r"\bC\s*\.?\s*S\s*\.?\b", "CENTRO SAUDE", texto)
    texto = texto.replace("CENTRO DE SAUDE", "CENTRO SAUDE")
    return re.sub(r"[^A-Z0-9]+", " ", texto).strip()


def _campos_descripcion(descripcion: str) -> dict[str, str]:
    texto = html.unescape(descripcion)
    filas = re.findall(
        r"<tr[^>]*>\s*<td[^>]*>\s*(.*?)\s*</td>\s*<td[^>]*>\s*(.*?)\s*</td>",
        texto,
        flags=re.IGNORECASE | re.DOTALL,
    )
    return {
        re.sub(r"<[^>]+>", "", clave).strip().upper():
        re.sub(r"<[^>]+>", "", valor).strip()
        for clave, valor in filas
    }


@lru_cache(maxsize=1)
def _cargar_centros() -> list[dict[str, str | None]]:
    if not KML_PATH.exists():
        raise RuntimeError("Non se atopou o catálogo sanitario da Xunta")

    raiz = ET.parse(KML_PATH).getroot()
    centros = []
    for marca in raiz.findall(".//kml:Placemark", KML_NS):
        nome = marca.findtext("kml:name", default="", namespaces=KML_NS).strip()
        descripcion = marca.findtext("kml:description", default="", namespaces=KML_NS)
        campos = _campos_descripcion(descripcion)
        telefono = campos.get("TELEFONO")
        if not nome or not telefono:
            continue
        centros.append({
            "nome": campos.get("NOMBRE") or nome,
            "nome_normalizado": _normalizar(campos.get("NOMBRE") or nome),
            "telefono": telefono,
            "enderezo": campos.get("DIRECCION"),
            "concello": campos.get("CONCELLO"),
        })
    return centros


@router.get("/buscar")
async def buscar_centro(nome: str = Query(..., min_length=2)):
    consulta = _normalizar(nome)
    try:
        centros = _cargar_centros()
    except (OSError, ET.ParseError, RuntimeError) as erro:
        raise HTTPException(status_code=503, detail=str(erro)) from erro

    candidatos = []
    for centro in centros:
        nome_centro = str(centro["nome_normalizado"])
        coincidencia = SequenceMatcher(None, consulta, nome_centro).ratio()
        if consulta in nome_centro or nome_centro in consulta:
            coincidencia += 1
        candidatos.append((coincidencia, centro))

    if not candidatos:
        raise HTTPException(status_code=404, detail="Non se atopou o centro sanitario")

    puntuacion, centro = max(candidatos, key=lambda candidato: candidato[0])
    if puntuacion < 0.45:
        raise HTTPException(status_code=404, detail="Non se atopou o centro sanitario")

    return {
        "nome": centro["nome"],
        "enderezo": centro["enderezo"],
        "concello": centro["concello"],
        "telefono": centro["telefono"],
        "fonte": "Xunta de Galicia - Mapa dos servizos sanitarios (CC BY-SA 4.0)",
    }
