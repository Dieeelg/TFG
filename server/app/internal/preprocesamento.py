"""Preprocesamento conservador das imaxes antes do recoñecemento OCR.

As transformacións só se aplican cando hai evidencias suficientes de que a
folla está inclinada ou deformada pola perspectiva. Ante calquera dúbida ou
erro devólvense exactamente os bytes recibidos.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from typing import Optional

import cv2
import numpy as np


MAX_DIMENSION_DETECCION = 1600
MIN_DIMENSION_IMAXE = 160
MIN_AREA_FOLLA = 0.38
MAX_AREA_FOLLA = 0.96
MIN_ANGULO_CORRECCION = 0.7
MAX_ANGULO_CORRECCION = 15.0
MAX_PIXELES_PREPROCESAMENTO = 30_000_000
MAX_LADO_AZURE = 10_000
MAX_BYTES_PREDETERMINADOS = 3_900_000


@dataclass(frozen=True)
class ResultadoPreprocesamento:
    """Resultado e datos de diagnóstico dunha tentativa de corrección."""

    contido: bytes
    aplicado: bool
    metodo: str
    motivo: str
    angulo: float = 0.0
    confianza: float = 0.0
    dimensions_orixinais: Optional[tuple[int, int]] = None
    dimensions_saida: Optional[tuple[int, int]] = None
    formato_saida: Optional[str] = None


def preprocesar_documento(
    contido: bytes,
    tipo_contido: Optional[str] = None,
    activado: Optional[bool] = None,
) -> ResultadoPreprocesamento:
    """Endereita unha imaxe cando a corrección se pode facer con seguridade.

    Os PDF, os formatos que OpenCV non pode decodificar e as deteccións de
    baixa confianza pasan sen modificacións. ``activado`` permite forzar o
    comportamento nas probas; se non se indica emprégase a variable de
    contorno ``PREPROCESS_IMAGES`` (activada por defecto).
    """

    if not contido:
        return _sen_cambios(contido, "ficheiro_baleiro")

    if not _preprocesamento_activado(activado):
        return _sen_cambios(contido, "desactivado")

    tipo = (tipo_contido or "").lower().split(";", 1)[0].strip()
    if tipo == "application/pdf" or contido.lstrip().startswith(b"%PDF-"):
        return _sen_cambios(contido, "pdf")

    if tipo in {"image/heic", "image/heif"} or _parece_heif(contido):
        return _sen_cambios(contido, "heif_non_decodificable")

    if tipo and not (tipo.startswith("image/") or tipo == "application/octet-stream"):
        return _sen_cambios(contido, "tipo_non_soportado")

    if len(contido) > _limite_bytes_saida():
        return _sen_cambios(contido, "ficheiro_supera_limite_preprocesamento")

    try:
        datos = np.frombuffer(contido, dtype=np.uint8)
        imaxe = cv2.imdecode(datos, cv2.IMREAD_COLOR)
        if imaxe is None:
            return _sen_cambios(contido, "imaxe_non_decodificable")

        alto, ancho = imaxe.shape[:2]
        dimensions = (ancho, alto)
        if min(ancho, alto) < MIN_DIMENSION_IMAXE:
            return _sen_cambios(contido, "imaxe_demasiado_pequena", dimensions)
        if max(ancho, alto) > MAX_LADO_AZURE or ancho * alto > MAX_PIXELES_PREPROCESAMENTO:
            return _sen_cambios(contido, "dimensions_fora_do_limite", dimensions)

        imaxe_deteccion, escala = _preparar_deteccion(imaxe)
        gris, bordos = _detectar_bordos(imaxe_deteccion)

        candidato = _buscar_folla(gris, bordos)
        if candidato is not None:
            cuadrilatero, confianza = candidato
            resultado = _corrixir_perspectiva(
                contido,
                imaxe,
                cuadrilatero / escala,
                confianza,
                tipo,
            )
            if resultado is not None:
                return resultado

        correccion = _estimar_inclinacion(bordos)
        if correccion is None:
            return _sen_cambios(contido, "deteccion_sen_confianza", dimensions)

        angulo, confianza = correccion
        if abs(angulo) < MIN_ANGULO_CORRECCION:
            return _sen_cambios(contido, "imaxe_xa_recta", dimensions)

        ancho_rotada, alto_rotada = _dimensions_rotacion(ancho, alto, angulo)
        if (
            max(ancho_rotada, alto_rotada) > MAX_LADO_AZURE
            or ancho_rotada * alto_rotada > MAX_PIXELES_PREPROCESAMENTO
        ):
            return _sen_cambios(contido, "saida_supera_limite_de_dimensions", dimensions)
        rotada = _rotar_sen_recortar(imaxe, angulo)
        codificado = _codificar(rotada, tipo, contido)
        if codificado is None:
            return _sen_cambios(contido, "erro_de_codificacion", dimensions)

        datos_saida, formato = codificado
        alto_saida, ancho_saida = rotada.shape[:2]
        return ResultadoPreprocesamento(
            contido=datos_saida,
            aplicado=True,
            metodo="inclinacion",
            motivo="linas_con_orientacion_consistente",
            angulo=round(float(angulo), 2),
            confianza=round(float(confianza), 3),
            dimensions_orixinais=dimensions,
            dimensions_saida=(ancho_saida, alto_saida),
            formato_saida=formato,
        )
    except (cv2.error, MemoryError, ValueError, TypeError) as erro:
        logging.warning("Non se puido preprocesar a imaxe: %s", type(erro).__name__)
        return _sen_cambios(contido, "erro_de_preprocesamento")
    except Exception as erro:  # O preprocesamento nunca debe bloquear o OCR.
        logging.warning("Erro inesperado no preprocesamento: %s", type(erro).__name__)
        return _sen_cambios(contido, "erro_inesperado")


def _preprocesamento_activado(valor: Optional[bool]) -> bool:
    if valor is not None:
        return valor
    return os.getenv("PREPROCESS_IMAGES", "true").strip().lower() not in {
        "0",
        "false",
        "non",
        "no",
        "off",
    }


def _limite_bytes_saida() -> int:
    try:
        return max(10_000, int(os.getenv("PREPROCESS_MAX_BYTES", MAX_BYTES_PREDETERMINADOS)))
    except (TypeError, ValueError):
        return MAX_BYTES_PREDETERMINADOS


def _parece_heif(contido: bytes) -> bool:
    if len(contido) < 12 or contido[4:8] != b"ftyp":
        return False
    marca = contido[8:12].lower()
    return marca in {b"heic", b"heix", b"hevc", b"hevx", b"mif1", b"msf1"}


def _sen_cambios(
    contido: bytes,
    motivo: str,
    dimensions: Optional[tuple[int, int]] = None,
) -> ResultadoPreprocesamento:
    return ResultadoPreprocesamento(
        contido=contido,
        aplicado=False,
        metodo="sen_cambios",
        motivo=motivo,
        dimensions_orixinais=dimensions,
        dimensions_saida=dimensions,
    )


def _preparar_deteccion(imaxe: np.ndarray) -> tuple[np.ndarray, float]:
    alto, ancho = imaxe.shape[:2]
    escala = min(1.0, MAX_DIMENSION_DETECCION / float(max(ancho, alto)))
    if escala == 1.0:
        return imaxe, escala
    reducida = cv2.resize(imaxe, None, fx=escala, fy=escala, interpolation=cv2.INTER_AREA)
    return reducida, escala


def _detectar_bordos(imaxe: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    gris = cv2.cvtColor(imaxe, cv2.COLOR_BGR2GRAY)
    suavizada = cv2.GaussianBlur(gris, (5, 5), 0)
    mediana = float(np.median(suavizada))
    limiar_baixo = int(max(30, 0.66 * mediana))
    limiar_alto = int(min(220, max(limiar_baixo + 40, 1.33 * mediana)))
    bordos = cv2.Canny(suavizada, limiar_baixo, limiar_alto)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    bordos = cv2.morphologyEx(bordos, cv2.MORPH_CLOSE, kernel, iterations=1)
    return gris, bordos


def _buscar_folla(
    gris: np.ndarray,
    bordos: np.ndarray,
) -> Optional[tuple[np.ndarray, float]]:
    alto, ancho = gris.shape[:2]
    area_imaxe = float(alto * ancho)
    contornos, _ = cv2.findContours(bordos, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    mellor: Optional[tuple[np.ndarray, float]] = None
    mellor_area = 0.0

    for contorno in sorted(contornos, key=cv2.contourArea, reverse=True)[:30]:
        perimetro = cv2.arcLength(contorno, True)
        if perimetro <= 0:
            continue

        aproximacion = None
        for epsilon in (0.015, 0.02, 0.025, 0.03):
            posible = cv2.approxPolyDP(contorno, epsilon * perimetro, True)
            if len(posible) == 4:
                aproximacion = posible
                break
        if aproximacion is None or not cv2.isContourConvex(aproximacion):
            continue

        puntos = _ordenar_puntos(aproximacion.reshape(4, 2).astype(np.float32))
        if len(np.unique(np.rint(puntos), axis=0)) != 4:
            continue

        area = abs(cv2.contourArea(puntos))
        proporcion_area = area / area_imaxe
        if not MIN_AREA_FOLLA <= proporcion_area <= MAX_AREA_FOLLA:
            continue

        angulos = _angulos_interiores(puntos)
        if any(angulo < 55.0 or angulo > 125.0 for angulo in angulos):
            continue

        lados = _lonxitudes_lados(puntos)
        if min(lados) < 0.28 * min(ancho, alto):
            continue
        if min(lados) / max(lados) < 0.42:
            continue

        centro = puntos.mean(axis=0)
        distancia_centro = np.linalg.norm(centro - np.array([ancho / 2, alto / 2]))
        if distancia_centro > 0.24 * np.hypot(ancho, alto):
            continue

        soportes = _soporte_de_bordo(bordos, puntos)
        soporte = float(np.mean(soportes))
        contraste = _contraste_do_contorno(gris, puntos)
        if min(soportes) < 0.35 or sum(valor >= 0.55 for valor in soportes) < 3:
            continue
        if soporte < 0.55 or contraste < 8.0:
            continue

        puntuacion_area = min(1.0, proporcion_area / 0.65)
        puntuacion_angulos = max(0.0, 1.0 - np.mean(np.abs(np.array(angulos) - 90.0)) / 35.0)
        puntuacion_contraste = min(1.0, contraste / 35.0)
        confianza = (
            0.25 * puntuacion_area
            + 0.25 * puntuacion_angulos
            + 0.30 * soporte
            + 0.20 * puntuacion_contraste
        )
        if confianza < 0.72:
            continue

        # Entre candidatos fiables prefírese a silueta de maior área. Isto
        # evita escoller un marco impreso situado uns píxeles dentro do papel.
        if mellor is None or proporcion_area > mellor_area:
            mellor = (puntos, float(confianza))
            mellor_area = proporcion_area

    return mellor


def _ordenar_puntos(puntos: np.ndarray) -> np.ndarray:
    suma = puntos.sum(axis=1)
    diferenza = np.diff(puntos, axis=1).reshape(-1)
    return np.array(
        [
            puntos[np.argmin(suma)],
            puntos[np.argmin(diferenza)],
            puntos[np.argmax(suma)],
            puntos[np.argmax(diferenza)],
        ],
        dtype=np.float32,
    )


def _angulos_interiores(puntos: np.ndarray) -> list[float]:
    angulos = []
    for indice, punto in enumerate(puntos):
        anterior = puntos[(indice - 1) % 4] - punto
        seguinte = puntos[(indice + 1) % 4] - punto
        denominador = np.linalg.norm(anterior) * np.linalg.norm(seguinte)
        if denominador == 0:
            return [0.0] * 4
        coseno = np.clip(np.dot(anterior, seguinte) / denominador, -1.0, 1.0)
        angulos.append(float(np.degrees(np.arccos(coseno))))
    return angulos


def _lonxitudes_lados(puntos: np.ndarray) -> list[float]:
    return [
        float(np.linalg.norm(puntos[(indice + 1) % 4] - puntos[indice]))
        for indice in range(4)
    ]


def _soporte_de_bordo(bordos: np.ndarray, puntos: np.ndarray) -> list[float]:
    grosor = max(3, int(round(max(bordos.shape) * 0.004)))
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * grosor + 1, 2 * grosor + 1))
    dilatados = cv2.dilate(bordos, kernel)
    soportes = []
    for indice in range(4):
        inicio = puntos[indice]
        fin = puntos[(indice + 1) % 4]
        mostras = max(40, int(np.linalg.norm(fin - inicio)))
        xs = np.linspace(inicio[0], fin[0], mostras).round().astype(int)
        ys = np.linspace(inicio[1], fin[1], mostras).round().astype(int)
        xs = np.clip(xs, 0, bordos.shape[1] - 1)
        ys = np.clip(ys, 0, bordos.shape[0] - 1)
        soportes.append(float(np.mean(dilatados[ys, xs] > 0)))
    return soportes


def _contraste_do_contorno(gris: np.ndarray, puntos: np.ndarray) -> float:
    # Compáranse mostras afastadas da propia liña do contorno. Deste xeito,
    # unha caixa ou unha táboa impresa dentro da folla non se confunde coa
    # silueta exterior do papel.
    # A banda queda suficientemente afastada para non medir un marco impreso
    # preto que estea situado xusto no bordo da folla.
    desprazamento = max(8.0, min(gris.shape) * 0.03)
    contrastes = []
    for indice in range(4):
        inicio = puntos[indice]
        fin = puntos[(indice + 1) % 4]
        vector = fin - inicio
        lonxitude = float(np.linalg.norm(vector))
        if lonxitude == 0:
            return 0.0
        normal_interior = np.array([-vector[1], vector[0]], dtype=np.float32) / lonxitude
        proporcions = np.linspace(0.12, 0.88, max(40, int(lonxitude / 4)))
        base = inicio[None, :] + proporcions[:, None] * vector[None, :]
        interior = base + normal_interior[None, :] * desprazamento
        exterior = base - normal_interior[None, :] * desprazamento

        xi = np.clip(np.rint(interior[:, 0]).astype(int), 0, gris.shape[1] - 1)
        yi = np.clip(np.rint(interior[:, 1]).astype(int), 0, gris.shape[0] - 1)
        xe = np.clip(np.rint(exterior[:, 0]).astype(int), 0, gris.shape[1] - 1)
        ye = np.clip(np.rint(exterior[:, 1]).astype(int), 0, gris.shape[0] - 1)
        contrastes.append(float(np.median(gris[yi, xi])) - float(np.median(gris[ye, xe])))

    # O percentil 25 obriga a que, como mínimo, tres lados presenten un
    # contraste compatible cun límite real da folla.
    return float(np.percentile(contrastes, 25))


def _corrixir_perspectiva(
    contido: bytes,
    imaxe: np.ndarray,
    puntos: np.ndarray,
    confianza: float,
    tipo_contido: str,
) -> Optional[ResultadoPreprocesamento]:
    alto, ancho = imaxe.shape[:2]
    dimensions = (ancho, alto)
    lados = _lonxitudes_lados(puntos)
    angulos_lados = []
    for indice in range(4):
        vector = puntos[(indice + 1) % 4] - puntos[indice]
        angulos_lados.append(_normalizar_angulo(np.degrees(np.arctan2(vector[1], vector[0]))))

    inclinacion = float(np.median(angulos_lados))
    diferenza_anchos = abs(lados[0] - lados[2]) / max(lados[0], lados[2])
    diferenza_altos = abs(lados[1] - lados[3]) / max(lados[1], lados[3])
    deformacion = max(diferenza_anchos, diferenza_altos)
    if abs(inclinacion) < MIN_ANGULO_CORRECCION and deformacion < 0.035:
        return _sen_cambios(contido, "imaxe_xa_recta", dimensions)
    if abs(inclinacion) > MAX_ANGULO_CORRECCION:
        return None

    centro = puntos.mean(axis=0)
    # Engádese unha marxe pequena para non cortar texto situado xunto a un
    # bordo impreso que se detectase lixeiramente dentro da silueta do papel.
    marxe = centro + (puntos - centro) * 1.04
    marxe[:, 0] = np.clip(marxe[:, 0], 0, ancho - 1)
    marxe[:, 1] = np.clip(marxe[:, 1], 0, alto - 1)
    superior_esq, superior_der, inferior_der, inferior_esq = marxe

    ancho_superior = np.linalg.norm(superior_der - superior_esq)
    ancho_inferior = np.linalg.norm(inferior_der - inferior_esq)
    alto_esquerdo = np.linalg.norm(inferior_esq - superior_esq)
    alto_dereito = np.linalg.norm(inferior_der - superior_der)
    ancho_saida = int(round(max(ancho_superior, ancho_inferior)))
    alto_saida = int(round(max(alto_esquerdo, alto_dereito)))
    if min(ancho_saida, alto_saida) < MIN_DIMENSION_IMAXE:
        return None
    if max(ancho_saida, alto_saida) > MAX_LADO_AZURE:
        return None
    if ancho_saida * alto_saida > 1.35 * ancho * alto:
        return None

    destino = np.array(
        [
            [0, 0],
            [ancho_saida - 1, 0],
            [ancho_saida - 1, alto_saida - 1],
            [0, alto_saida - 1],
        ],
        dtype=np.float32,
    )
    matriz = cv2.getPerspectiveTransform(marxe.astype(np.float32), destino)
    corrixida = cv2.warpPerspective(
        imaxe,
        matriz,
        (ancho_saida, alto_saida),
        flags=cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(255, 255, 255),
    )
    codificado = _codificar(corrixida, tipo_contido, contido)
    if codificado is None:
        return _sen_cambios(contido, "saida_non_valida", dimensions)
    datos_saida, formato = codificado
    return ResultadoPreprocesamento(
        contido=datos_saida,
        aplicado=True,
        metodo="perspectiva",
        motivo="catro_bordos_detectados",
        angulo=round(inclinacion, 2),
        confianza=round(confianza, 3),
        dimensions_orixinais=dimensions,
        dimensions_saida=(ancho_saida, alto_saida),
        formato_saida=formato,
    )


def _estimar_inclinacion(bordos: np.ndarray) -> Optional[tuple[float, float]]:
    dimension = max(bordos.shape)
    linhas = cv2.HoughLinesP(
        bordos,
        1,
        np.pi / 1800,
        threshold=max(45, int(dimension * 0.035)),
        minLineLength=max(50, int(dimension * 0.16)),
        maxLineGap=max(10, int(dimension * 0.025)),
    )
    if linhas is None:
        return None

    angulos = []
    pesos = []
    for x1, y1, x2, y2 in linhas[:, 0]:
        dx = float(x2 - x1)
        dy = float(y2 - y1)
        lonxitude = float(np.hypot(dx, dy))
        if lonxitude < dimension * 0.16:
            continue
        angulo = _normalizar_angulo(np.degrees(np.arctan2(dy, dx)))
        if abs(angulo) <= MAX_ANGULO_CORRECCION:
            angulos.append(angulo)
            pesos.append(lonxitude)

    if len(angulos) < 5:
        return None

    valores = np.asarray(angulos, dtype=float)
    pesos_array = np.asarray(pesos, dtype=float)
    mediana = _mediana_ponderada(valores, pesos_array)
    distancias = np.abs(valores - mediana)
    mascara = distancias <= 2.0
    if int(np.count_nonzero(mascara)) < 4:
        return None

    consenso = float(pesos_array[mascara].sum() / pesos_array.sum())
    desviacion = _mediana_ponderada(distancias[mascara], pesos_array[mascara])
    if consenso < 0.65 or desviacion > 1.5:
        return None

    confianza = min(0.97, 0.45 + 0.45 * consenso + 0.10 * (1.0 - desviacion / 1.5))
    return float(mediana), float(confianza)


def _normalizar_angulo(angulo: float) -> float:
    while angulo <= -45.0:
        angulo += 90.0
    while angulo > 45.0:
        angulo -= 90.0
    return float(angulo)


def _mediana_ponderada(valores: np.ndarray, pesos: np.ndarray) -> float:
    orde = np.argsort(valores)
    valores_ordenados = valores[orde]
    pesos_ordenados = pesos[orde]
    acumulados = np.cumsum(pesos_ordenados)
    indice = int(np.searchsorted(acumulados, pesos_ordenados.sum() / 2.0, side="left"))
    return float(valores_ordenados[min(indice, len(valores_ordenados) - 1)])


def _rotar_sen_recortar(imaxe: np.ndarray, angulo: float) -> np.ndarray:
    alto, ancho = imaxe.shape[:2]
    centro = (ancho / 2.0, alto / 2.0)
    matriz = cv2.getRotationMatrix2D(centro, angulo, 1.0)
    novo_ancho, novo_alto = _dimensions_rotacion(ancho, alto, angulo)
    matriz[0, 2] += novo_ancho / 2.0 - centro[0]
    matriz[1, 2] += novo_alto / 2.0 - centro[1]
    return cv2.warpAffine(
        imaxe,
        matriz,
        (novo_ancho, novo_alto),
        flags=cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(255, 255, 255),
    )


def _dimensions_rotacion(ancho: int, alto: int, angulo: float) -> tuple[int, int]:
    radiáns = np.radians(angulo)
    coseno = abs(float(np.cos(radiáns)))
    seno = abs(float(np.sin(radiáns)))
    novo_ancho = int(np.ceil(alto * seno + ancho * coseno))
    novo_alto = int(np.ceil(alto * coseno + ancho * seno))
    return novo_ancho, novo_alto


def _codificar(
    imaxe: np.ndarray,
    tipo_contido: str,
    contido_orixinal: bytes,
) -> Optional[tuple[bytes, str]]:
    e_png = tipo_contido == "image/png" or contido_orixinal.startswith(b"\x89PNG\r\n\x1a\n")
    if e_png:
        correcto, datos = cv2.imencode(".png", imaxe, [cv2.IMWRITE_PNG_COMPRESSION, 3])
        formato = "png"
    else:
        parametros = [cv2.IMWRITE_JPEG_QUALITY, 97]
        if hasattr(cv2, "IMWRITE_JPEG_SAMPLING_FACTOR_444"):
            parametros.extend(
                [
                    cv2.IMWRITE_JPEG_SAMPLING_FACTOR,
                    cv2.IMWRITE_JPEG_SAMPLING_FACTOR_444,
                ]
            )
        correcto, datos = cv2.imencode(".jpg", imaxe, parametros)
        formato = "jpg"
    if not correcto:
        return None
    resultado = datos.tobytes()
    if len(resultado) > _limite_bytes_saida():
        return None
    return resultado, formato
