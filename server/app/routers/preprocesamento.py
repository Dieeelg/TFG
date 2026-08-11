"""Endpoint de diagnóstico visual do preprocesamento de documentos."""

from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import Response

from app.internal.preprocesamento import ResultadoPreprocesamento, preprocesar_documento
from app.schemas.models import ErrorResponse


TIPOS_SOPORTADOS = {
    "image/jpeg",
    "image/png",
    "image/heic",
    "image/heif",
    "application/pdf",
    "application/octet-stream",
}

router = APIRouter(
    prefix="/preprocesamento",
    tags=["Preprocesamento de informes"],
)


@router.post(
    "/",
    response_class=Response,
    summary="Preprocesar un informe sen executar o OCR",
    description=(
        "Aplica exactamente o mesmo preprocesamento empregado por /extraccion/ "
        "e devolve o ficheiro resultante para poder revisalo visualmente."
    ),
    responses={
        200: {
            "description": "Imaxe preprocesada ou ficheiro orixinal se non se aplicou ningún cambio",
            "content": {
                "image/jpeg": {},
                "image/png": {},
                "image/heic": {},
                "image/heif": {},
                "application/pdf": {},
                "application/octet-stream": {},
            },
        },
        400: {
            "model": ErrorResponse,
            "description": "Tipo de ficheiro non soportado",
        },
    },
)
async def probar_preprocesamento(
    file: UploadFile = File(
        ...,
        description="Imaxe ou PDF que se quere preprocesar (JPEG, PNG, HEIC ou PDF)",
    ),
) -> Response:
    tipo_contido = (file.content_type or "application/octet-stream").lower().split(";", 1)[0]
    if tipo_contido not in TIPOS_SOPORTADOS:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo de ficheiro non soportado: {file.content_type}",
        )

    contido = await file.read()
    resultado = preprocesar_documento(contido, tipo_contido)
    tipo_saida, extension = _tipo_e_extension_saida(resultado, tipo_contido)
    headers = _headers_diagnostico(resultado)
    headers["Content-Disposition"] = f'inline; filename="preprocesada.{extension}"'
    return Response(
        content=resultado.contido,
        media_type=tipo_saida,
        headers=headers,
    )


def _tipo_e_extension_saida(
    resultado: ResultadoPreprocesamento,
    tipo_entrada: str,
) -> tuple[str, str]:
    if resultado.formato_saida == "png":
        return "image/png", "png"
    if resultado.formato_saida in {"jpg", "jpeg"}:
        return "image/jpeg", "jpg"

    extensions = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/heic": "heic",
        "image/heif": "heif",
        "application/pdf": "pdf",
        "application/octet-stream": "bin",
    }
    return tipo_entrada, extensions.get(tipo_entrada, "bin")


def _headers_diagnostico(resultado: ResultadoPreprocesamento) -> dict[str, str]:
    def dimensions(valor: tuple[int, int] | None) -> str:
        return "" if valor is None else f"{valor[0]}x{valor[1]}"

    return {
        "X-Preprocesamento-Aplicado": str(resultado.aplicado).lower(),
        "X-Preprocesamento-Metodo": resultado.metodo,
        "X-Preprocesamento-Motivo": resultado.motivo,
        "X-Preprocesamento-Angulo": str(resultado.angulo),
        "X-Preprocesamento-Confianza": str(resultado.confianza),
        "X-Preprocesamento-Dimensions-Orixinais": dimensions(resultado.dimensions_orixinais),
        "X-Preprocesamento-Dimensions-Saida": dimensions(resultado.dimensions_saida),
    }
