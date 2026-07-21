"""Garda localmente o resultado do preprocesamento dunha fotografía.

Exemplo desde a raíz do repositorio:

    .venv\Scripts\python.exe server\scripts\probar_preprocesamento.py foto.jpg
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import sys
from dataclasses import asdict
from datetime import datetime
from pathlib import Path


RAIZ_SERVER = Path(__file__).resolve().parents[1]
if str(RAIZ_SERVER) not in sys.path:
    sys.path.insert(0, str(RAIZ_SERVER))

from app.internal.preprocesamento import preprocesar_documento  # noqa: E402


def _crear_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Endereita unha imaxe e garda o resultado para revisalo antes de integrar o cambio."
    )
    parser.add_argument("imaxe", type=Path, help="Ruta da imaxe que se quere probar")
    parser.add_argument(
        "--saida",
        type=Path,
        default=RAIZ_SERVER / "tmp" / "preprocesamento",
        help="Directorio local de saída (por defecto: server/tmp/preprocesamento)",
    )
    return parser


def main() -> int:
    argumentos = _crear_parser().parse_args()
    ruta_imaxe = argumentos.imaxe.resolve()
    if not ruta_imaxe.is_file():
        print(f"Non se atopou a imaxe: {ruta_imaxe}", file=sys.stderr)
        return 2

    contido = ruta_imaxe.read_bytes()
    tipo_contido = mimetypes.guess_type(ruta_imaxe.name)[0] or "application/octet-stream"
    resultado = preprocesar_documento(contido, tipo_contido, activado=True)

    directorio_saida = argumentos.saida.resolve()
    directorio_saida.mkdir(parents=True, exist_ok=True)
    extension = f".{resultado.formato_saida}" if resultado.formato_saida else ruta_imaxe.suffix
    identificador = datetime.now().strftime("%Y%m%d-%H%M%S")
    ruta_resultado = directorio_saida / f"resultado-{identificador}{extension}"
    ruta_metadatos = directorio_saida / f"resultado-{identificador}.json"
    ruta_resultado.write_bytes(resultado.contido)

    metadatos = asdict(resultado)
    metadatos.pop("contido")
    ruta_metadatos.write_text(
        json.dumps(metadatos, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    estado = "transformada" if resultado.aplicado else "conservada sen cambios"
    print(f"Imaxe {estado}.")
    print(f"Método: {resultado.metodo}")
    print(f"Motivo: {resultado.motivo}")
    print(f"Ángulo estimado: {resultado.angulo}°")
    print(f"Confianza: {resultado.confianza}")
    print(f"Resultado: {ruta_resultado}")
    print(f"Diagnóstico: {ruta_metadatos}")
    print("Aviso: estes ficheiros son só para a proba local; elimínaos cando remates.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
