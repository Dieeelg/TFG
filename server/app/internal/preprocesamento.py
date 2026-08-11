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
MIN_AREA_FOLLA_CLARA = 0.24
MAX_AREA_FOLLA_CLARA = 0.82
MIN_ANGULO_CORRECCION = 1.0
MAX_ANGULO_PERSPECTIVA = 15.0
MAX_ANGULO_INCLINACION = 30.0
MIN_ANGULO_BORDOS_PARCIAIS = 12.0
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

        # Nunha fotografía real os bordos do papel poden ser suaves ou quedar
        # interrompidos por sombras. Como segunda vía búscase unha superficie
        # clara, pouco saturada e cunha xeometría compatible cunha folla. Esta
        # detección mantén requisitos de bordo e contraste para non confundir
        # unha zona branca da propia impresión coa silueta exterior.
        candidato_claro = _buscar_folla_clara(imaxe_deteccion, gris, bordos)
        if candidato_claro is not None:
            cuadrilatero, confianza = candidato_claro
            resultado = _corrixir_perspectiva(
                contido,
                imaxe,
                cuadrilatero / escala,
                confianza,
                tipo,
                motivo="silueta_clara_da_folla",
                max_angulo=MAX_ANGULO_INCLINACION,
            )
            if resultado is not None:
                return resultado

        correccion = _estimar_inclinacion(bordos)
        if correccion is None:
            return _sen_cambios(contido, "deteccion_sen_confianza", dimensions)

        angulo, confianza, puntos_linas = correccion

        # Se a folla está enriba doutra superficie branca, dous dos seus
        # bordos poden desaparecer visualmente e non formar un contorno
        # pechado. Esta terceira vía só se tenta con xiros amplos e reconstrúe
        # o cuadrilátero a partir de dous bordos físicos adxacentes. Os
        # requisitos son deliberadamente estritos para conservar intacto o
        # comportamento dos casos nos que os detectores anteriores xa van ben.
        if abs(angulo) >= MIN_ANGULO_BORDOS_PARCIAIS:
            candidato_parcial = _buscar_folla_con_bordos_parciais(
                imaxe_deteccion,
                gris,
                bordos,
                angulo,
                puntos_linas,
            )
            if candidato_parcial is not None:
                cuadrilatero, confianza_parcial = candidato_parcial
                resultado = _corrixir_perspectiva(
                    contido,
                    imaxe,
                    cuadrilatero / escala,
                    confianza_parcial,
                    tipo,
                    motivo="dous_bordos_da_folla_reconstruidos",
                    max_angulo=MAX_ANGULO_INCLINACION,
                )
                if resultado is not None:
                    return resultado

        if abs(angulo) < MIN_ANGULO_CORRECCION:
            return _sen_cambios(contido, "imaxe_xa_recta", dimensions)

        ancho_rotada, alto_rotada = _dimensions_rotacion(ancho, alto, angulo)
        if (
            max(ancho_rotada, alto_rotada) > MAX_LADO_AZURE
            or ancho_rotada * alto_rotada > MAX_PIXELES_PREPROCESAMENTO
        ):
            return _sen_cambios(contido, "saida_supera_limite_de_dimensions", dimensions)
        rotada = _rotar_e_recortar_recheo(
            imaxe,
            angulo,
            puntos_linas / escala,
        )
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


def _buscar_folla_clara(
    imaxe: np.ndarray,
    gris: np.ndarray,
    bordos: np.ndarray,
) -> Optional[tuple[np.ndarray, float]]:
    """Detecta unha folla clara sobre un fondo con cor ou textura.

    Empréganse varios limiares próximos de saturación porque a iluminación e
    o balance de brancos do móbil poden variar. Só se acepta un compoñente
    central, convexo, que non toque o marco da fotografía e cuxos lados
    coincidan maioritariamente con bordos reais da imaxe.
    """

    alto, ancho = gris.shape[:2]
    area_imaxe = float(alto * ancho)
    dimension = max(alto, ancho)
    hsv = cv2.cvtColor(imaxe, cv2.COLOR_BGR2HSV)
    saturacion = hsv[:, :, 1]
    luminosidade = hsv[:, :, 2]

    lado_peche = _impar(max(9, int(round(dimension * 0.013))))
    lado_apertura = _impar(max(5, int(round(dimension * 0.005))))
    kernel_peche = cv2.getStructuringElement(
        cv2.MORPH_RECT,
        (lado_peche, lado_peche),
    )
    kernel_apertura = cv2.getStructuringElement(
        cv2.MORPH_RECT,
        (lado_apertura, lado_apertura),
    )

    mellor: Optional[tuple[np.ndarray, float]] = None
    mellor_confianza = 0.0

    for limiar_saturacion in (8, 10, 12, 14):
        mascara = np.where(
            (saturacion < limiar_saturacion) & (luminosidade > 90),
            255,
            0,
        ).astype(np.uint8)
        mascara = cv2.morphologyEx(
            mascara,
            cv2.MORPH_CLOSE,
            kernel_peche,
            iterations=2,
        )
        mascara = cv2.morphologyEx(
            mascara,
            cv2.MORPH_OPEN,
            kernel_apertura,
            iterations=1,
        )

        contornos, _ = cv2.findContours(
            mascara,
            cv2.RETR_EXTERNAL,
            cv2.CHAIN_APPROX_SIMPLE,
        )
        for contorno in sorted(contornos, key=cv2.contourArea, reverse=True)[:12]:
            area = float(cv2.contourArea(contorno))
            proporcion_area = area / area_imaxe
            if not MIN_AREA_FOLLA_CLARA <= proporcion_area <= MAX_AREA_FOLLA_CLARA:
                continue

            envolvente = cv2.convexHull(contorno)
            area_envolvente = float(cv2.contourArea(envolvente))
            if area_envolvente <= 0 or area / area_envolvente < 0.92:
                continue

            perimetro = cv2.arcLength(envolvente, True)
            aproximacion = None
            for epsilon in (0.008, 0.01, 0.012, 0.015, 0.02, 0.025, 0.03):
                posible = cv2.approxPolyDP(envolvente, epsilon * perimetro, True)
                if len(posible) == 4 and cv2.isContourConvex(posible):
                    aproximacion = posible
                    break
            if aproximacion is None:
                continue

            puntos = _ordenar_puntos(aproximacion.reshape(4, 2).astype(np.float32))
            if len(np.unique(np.rint(puntos), axis=0)) != 4:
                continue

            marxe_imaxe = max(4, int(round(dimension * 0.004)))
            if np.any(
                (puntos[:, 0] <= marxe_imaxe)
                | (puntos[:, 0] >= ancho - 1 - marxe_imaxe)
                | (puntos[:, 1] <= marxe_imaxe)
                | (puntos[:, 1] >= alto - 1 - marxe_imaxe)
            ):
                continue

            angulos = _angulos_interiores(puntos)
            if any(angulo < 55.0 or angulo > 125.0 for angulo in angulos):
                continue

            lados = _lonxitudes_lados(puntos)
            if min(lados) < 0.22 * min(ancho, alto):
                continue
            if min(lados) / max(lados) < 0.42:
                continue

            centro = puntos.mean(axis=0)
            distancia_centro = np.linalg.norm(
                centro - np.array([ancho / 2.0, alto / 2.0])
            )
            if distancia_centro > 0.28 * np.hypot(ancho, alto):
                continue

            soportes = _soporte_de_bordo(bordos, puntos)
            soporte = float(np.mean(soportes))
            contraste = _contraste_do_contorno(gris, puntos)
            if sum(valor >= 0.50 for valor in soportes) < 3:
                continue
            if soporte < 0.55 or contraste < 12.0:
                continue

            puntuacion_angulos = max(
                0.0,
                1.0 - np.mean(np.abs(np.array(angulos) - 90.0)) / 35.0,
            )
            confianza = (
                0.20 * (area / area_envolvente)
                + 0.30 * soporte
                + 0.20 * min(1.0, contraste / 35.0)
                + 0.15 * puntuacion_angulos
                + 0.15 * min(1.0, proporcion_area / 0.50)
            )
            if confianza < 0.76:
                continue
            if mellor is None or confianza > mellor_confianza:
                mellor = (puntos, float(confianza))
                mellor_confianza = float(confianza)

    return mellor


def _impar(valor: int) -> int:
    return valor if valor % 2 else valor + 1


def _buscar_folla_con_bordos_parciais(
    imaxe: np.ndarray,
    gris: np.ndarray,
    bordos: np.ndarray,
    angulo: float,
    puntos_linas: np.ndarray,
) -> Optional[tuple[np.ndarray, float]]:
    """Reconstrúe unha folla cando só se ven dous bordos adxacentes.

    Esta situación aparece ao fotografar unha folla branca enriba doutra:
    a sombra marca dous lados, pero os outros quedan fundidos coa superficie
    inferior. Non se usa para xiros pequenos e cada lado aceptado debe separar
    superficies distintas; as liñas impresas teñen branco a ambos os lados e
    quedan descartadas por esa comprobación.
    """

    alto, ancho = gris.shape[:2]
    dimension = float(min(alto, ancho))
    area_imaxe = float(alto * ancho)
    detector = cv2.createLineSegmentDetector(cv2.LSD_REFINE_STD)
    detectadas = detector.detect(gris)[0]
    if detectadas is None:
        return None

    segmentos = []
    for x1, y1, x2, y2 in detectadas[:, 0]:
        inicio = np.array([x1, y1], dtype=np.float32)
        fin = np.array([x2, y2], dtype=np.float32)
        vector = fin - inicio
        lonxitude = float(np.linalg.norm(vector))
        if lonxitude < 0.18 * dimension:
            continue

        angulo_segmento = float(np.degrees(np.arctan2(vector[1], vector[0])))
        angulo_normalizado = _normalizar_angulo(angulo_segmento)
        if abs(angulo_normalizado - angulo) > 4.0:
            continue

        # A orientación canónica mantén coherentes o vector normal e a
        # distancia da liña á orixe, necesarias para agrupar fragmentos.
        orientacion = angulo_segmento % 180.0
        unidade = np.array(
            [np.cos(np.radians(orientacion)), np.sin(np.radians(orientacion))],
            dtype=np.float32,
        )
        normal = np.array([-unidade[1], unidade[0]], dtype=np.float32)
        distancia = float(np.dot((inicio + fin) / 2.0, normal))
        segmentos.append(
            {
                "angulo": orientacion,
                "unidade": unidade,
                "normal": normal,
                "distancia": distancia,
                "lonxitude": lonxitude,
                "puntos": [inicio, fin],
            }
        )

    if len(segmentos) < 2:
        return None

    grupos: list[dict] = []
    for segmento in sorted(segmentos, key=lambda valor: valor["lonxitude"], reverse=True):
        grupo_atopado = None
        for grupo in grupos:
            diferenza = abs(segmento["angulo"] - grupo["angulo"])
            diferenza = min(diferenza, 180.0 - diferenza)
            if diferenza <= 2.5 and abs(segmento["distancia"] - grupo["distancia"]) <= 0.018 * dimension:
                grupo_atopado = grupo
                break
        if grupo_atopado is None:
            grupos.append(segmento.copy())
        else:
            grupo_atopado["puntos"].extend(segmento["puntos"])
            grupo_atopado["lonxitude"] += segmento["lonxitude"]

    linhas = []
    for grupo in grupos:
        unidade = grupo["unidade"]
        puntos = np.asarray(grupo["puntos"], dtype=np.float32)
        proxeccions = puntos @ unidade
        inicio = unidade * float(proxeccions.min()) + grupo["normal"] * grupo["distancia"]
        fin = unidade * float(proxeccions.max()) + grupo["normal"] * grupo["distancia"]
        alcance = float(np.linalg.norm(fin - inicio))
        if alcance < 0.30 * dimension:
            continue
        contraste = _contraste_segmento(gris, inicio, fin)
        if contraste < 5.5:
            continue
        linhas.append(
            {
                "angulo": grupo["angulo"],
                "inicio": inicio,
                "fin": fin,
                "unidade": unidade,
                "normal": grupo["normal"],
                "distancia": grupo["distancia"],
                "alcance": alcance,
                "contraste": contraste,
            }
        )

    if len(linhas) < 2:
        return None

    hsv = cv2.cvtColor(imaxe, cv2.COLOR_BGR2HSV)
    mellor: Optional[tuple[np.ndarray, float]] = None
    mellor_confianza = 0.0
    for indice, primeira in enumerate(linhas):
        for segunda in linhas[indice + 1 :]:
            diferenza = abs(primeira["angulo"] - segunda["angulo"])
            diferenza = min(diferenza, 180.0 - diferenza)
            if not 78.0 <= diferenza <= 102.0:
                continue

            esquina = _interseccion_linhas(primeira, segunda)
            if esquina is None:
                continue
            if not (-0.04 * ancho <= esquina[0] <= 1.04 * ancho):
                continue
            if not (-0.04 * alto <= esquina[1] <= 1.04 * alto):
                continue

            extremos = []
            valido = True
            for linha in (primeira, segunda):
                candidatos = (linha["inicio"], linha["fin"])
                afastamentos = [float(np.linalg.norm(punto - esquina)) for punto in candidatos]
                distancia_proxima = min(afastamentos)
                distancia_longa = max(afastamentos)
                if distancia_proxima > 0.18 * distancia_longa:
                    valido = False
                    break
                extremo = candidatos[int(np.argmax(afastamentos))]
                vector = extremo - esquina
                if np.linalg.norm(vector) < 0.34 * dimension:
                    valido = False
                    break
                extremos.append(vector)
            if not valido:
                continue

            proporcion_lados = min(np.linalg.norm(extremos[0]), np.linalg.norm(extremos[1])) / max(
                np.linalg.norm(extremos[0]), np.linalg.norm(extremos[1])
            )
            if not 0.52 <= proporcion_lados <= 0.82:
                continue

            cuadrilatero = _ordenar_puntos(
                np.array(
                    [
                        esquina,
                        esquina + extremos[0],
                        esquina + extremos[0] + extremos[1],
                        esquina + extremos[1],
                    ],
                    dtype=np.float32,
                )
            )
            if len(np.unique(np.rint(cuadrilatero), axis=0)) != 4:
                continue
            if not cv2.isContourConvex(cuadrilatero.astype(np.int32)):
                continue

            proporcion_area = abs(cv2.contourArea(cuadrilatero)) / area_imaxe
            if not 0.24 <= proporcion_area <= 0.62:
                continue
            marxe = 0.035 * max(alto, ancho)
            if np.any(
                (cuadrilatero[:, 0] < -marxe)
                | (cuadrilatero[:, 0] > ancho - 1 + marxe)
                | (cuadrilatero[:, 1] < -marxe)
                | (cuadrilatero[:, 1] > alto - 1 + marxe)
            ):
                continue

            centro = cuadrilatero.mean(axis=0)
            if np.linalg.norm(centro - np.array([ancho / 2.0, alto / 2.0])) > 0.24 * np.hypot(ancho, alto):
                continue

            dentro = np.array(
                [cv2.pointPolygonTest(cuadrilatero, tuple(map(float, punto)), False) >= 0 for punto in puntos_linas],
                dtype=bool,
            )
            proporcion_linas_dentro = float(np.mean(dentro)) if len(dentro) else 0.0
            if proporcion_linas_dentro < 0.82:
                continue

            mascara = np.zeros((alto, ancho), dtype=np.uint8)
            cv2.fillConvexPoly(mascara, np.rint(cuadrilatero).astype(np.int32), 255)
            erosion = max(5, _impar(int(round(dimension * 0.025))))
            interior = cv2.erode(mascara, np.ones((erosion, erosion), dtype=np.uint8)) > 0
            if not np.any(interior):
                continue
            proporcion_papel = float(
                np.mean((hsv[:, :, 1][interior] <= 22) & (hsv[:, :, 2][interior] >= 105))
            )
            if proporcion_papel < 0.76:
                continue

            soportes = _soporte_de_bordo(bordos, cuadrilatero)
            contrastes = _contrastes_dos_lados(gris, cuadrilatero)
            lados_fisicos = sum(
                soporte >= 0.55 and abs(contraste) >= 5.5
                for soporte, contraste in zip(soportes, contrastes)
            )
            # Tres ou catro lados visibles pertencen ao detector de contornos
            # normal. Este fallback queda reservado ao caso ambiguo de dous.
            if lados_fisicos != 2:
                continue

            confianza = (
                0.24 * min(1.0, proporcion_linas_dentro)
                + 0.22 * min(1.0, proporcion_papel)
                + 0.20 * min(1.0, np.mean(sorted(soportes, reverse=True)[:2]))
                + 0.18 * min(1.0, np.mean(sorted(map(abs, contrastes), reverse=True)[:2]) / 18.0)
                + 0.16 * min(1.0, proporcion_area / 0.36)
            )
            if confianza >= 0.78 and confianza > mellor_confianza:
                mellor = (cuadrilatero, float(confianza))
                mellor_confianza = float(confianza)

    return mellor


def _contraste_segmento(gris: np.ndarray, inicio: np.ndarray, fin: np.ndarray) -> float:
    vector = fin - inicio
    lonxitude = float(np.linalg.norm(vector))
    if lonxitude == 0:
        return 0.0
    normal = np.array([-vector[1], vector[0]], dtype=np.float32) / lonxitude
    desprazamento = max(7.0, min(gris.shape) * 0.018)
    proporcions = np.linspace(0.12, 0.88, max(40, int(lonxitude / 4)))
    base = inicio[None, :] + proporcions[:, None] * vector[None, :]
    medianas = []
    for signo in (-1.0, 1.0):
        mostras = base + signo * normal[None, :] * desprazamento
        xs = np.clip(np.rint(mostras[:, 0]).astype(int), 0, gris.shape[1] - 1)
        ys = np.clip(np.rint(mostras[:, 1]).astype(int), 0, gris.shape[0] - 1)
        medianas.append(float(np.median(gris[ys, xs])))
    return abs(medianas[0] - medianas[1])


def _interseccion_linhas(primeira: dict, segunda: dict) -> Optional[np.ndarray]:
    matriz = np.array([primeira["normal"], segunda["normal"]], dtype=np.float64)
    determinante = float(np.linalg.det(matriz))
    if abs(determinante) < 1e-4:
        return None
    termos = np.array([primeira["distancia"], segunda["distancia"]], dtype=np.float64)
    return np.linalg.solve(matriz, termos).astype(np.float32)


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
    contrastes = _contrastes_dos_lados(gris, puntos)

    # O percentil 25 obriga a que, como mínimo, tres lados presenten un
    # contraste compatible cun límite real da folla.
    return float(np.percentile(contrastes, 25))


def _contrastes_dos_lados(gris: np.ndarray, puntos: np.ndarray) -> list[float]:
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

    return contrastes


def _corrixir_perspectiva(
    contido: bytes,
    imaxe: np.ndarray,
    puntos: np.ndarray,
    confianza: float,
    tipo_contido: str,
    motivo: str = "catro_bordos_detectados",
    max_angulo: float = MAX_ANGULO_PERSPECTIVA,
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
    if abs(inclinacion) > max_angulo:
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
        motivo=motivo,
        angulo=round(inclinacion, 2),
        confianza=round(confianza, 3),
        dimensions_orixinais=dimensions,
        dimensions_saida=(ancho_saida, alto_saida),
        formato_saida=formato,
    )


def _estimar_inclinacion(
    bordos: np.ndarray,
) -> Optional[tuple[float, float, np.ndarray]]:
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
    segmentos = []
    for x1, y1, x2, y2 in linhas[:, 0]:
        dx = float(x2 - x1)
        dy = float(y2 - y1)
        lonxitude = float(np.hypot(dx, dy))
        if lonxitude < dimension * 0.16:
            continue
        angulo = _normalizar_angulo(np.degrees(np.arctan2(dy, dx)))
        if abs(angulo) <= MAX_ANGULO_INCLINACION:
            angulos.append(angulo)
            pesos.append(lonxitude)
            segmentos.append((float(x1), float(y1), float(x2), float(y2)))

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
    segmentos_array = np.asarray(segmentos, dtype=float)[mascara]
    puntos_linas = segmentos_array.reshape(-1, 2)
    return float(mediana), float(confianza), puntos_linas


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


def _rotar_e_recortar_recheo(
    imaxe: np.ndarray,
    angulo: float,
    puntos_linas: np.ndarray,
) -> np.ndarray:
    """Rota o lenzo e reduce de forma conservadora o recheo branco creado.

    O recorte só se tenta en xiros amplos. Retense como mínimo o 80 % dos
    píxeles procedentes da fotografía e garántese que as liñas que xustifican
    a corrección queden dentro cunha marxe ampla. Non se pretende inferir o
    bordo da folla: só reducir os triángulos artificiais da rotación.
    """

    alto, ancho = imaxe.shape[:2]
    centro = (ancho / 2.0, alto / 2.0)
    matriz = cv2.getRotationMatrix2D(centro, angulo, 1.0)
    novo_ancho, novo_alto = _dimensions_rotacion(ancho, alto, angulo)
    matriz[0, 2] += novo_ancho / 2.0 - centro[0]
    matriz[1, 2] += novo_alto / 2.0 - centro[1]
    rotada = cv2.warpAffine(
        imaxe,
        matriz,
        (novo_ancho, novo_alto),
        flags=cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(255, 255, 255),
    )
    if abs(angulo) < 10.0:
        return rotada

    mascara_orixe = np.full((alto, ancho), 255, dtype=np.uint8)
    mascara_rotada = cv2.warpAffine(
        mascara_orixe,
        matriz,
        (novo_ancho, novo_alto),
        flags=cv2.INTER_NEAREST,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    )
    valida = mascara_rotada > 0
    total_validos = int(np.count_nonzero(valida))
    if total_validos == 0:
        return rotada

    limiar_inicial = min(0.35, max(0.15, abs(angulo) / 75.0))
    recorte = None
    for limiar in np.arange(limiar_inicial, 0.09, -0.05):
        filas = np.flatnonzero(np.mean(valida, axis=1) >= limiar)
        columnas = np.flatnonzero(np.mean(valida, axis=0) >= limiar)
        if len(filas) == 0 or len(columnas) == 0:
            continue
        x1, x2 = int(columnas[0]), int(columnas[-1] + 1)
        y1, y2 = int(filas[0]), int(filas[-1] + 1)
        retidos = int(np.count_nonzero(valida[y1:y2, x1:x2])) / total_validos
        if retidos >= 0.80:
            recorte = [x1, y1, x2, y2]
            break
    if recorte is None:
        return rotada

    x1, y1, x2, y2 = recorte
    transformados = cv2.transform(
        puntos_linas.astype(np.float32).reshape(-1, 1, 2),
        matriz,
    ).reshape(-1, 2)
    marxe_contido = max(40, int(round(min(ancho, alto) * 0.12)))
    x1 = min(x1, max(0, int(np.floor(transformados[:, 0].min())) - marxe_contido))
    y1 = min(y1, max(0, int(np.floor(transformados[:, 1].min())) - marxe_contido))
    x2 = max(
        x2,
        min(novo_ancho, int(np.ceil(transformados[:, 0].max())) + marxe_contido),
    )
    y2 = max(
        y2,
        min(novo_alto, int(np.ceil(transformados[:, 1].max())) + marxe_contido),
    )

    if x2 - x1 < 0.72 * ancho or y2 - y1 < 0.72 * alto:
        return rotada
    if (x2 - x1) * (y2 - y1) > 0.96 * novo_ancho * novo_alto:
        return rotada
    return rotada[y1:y2, x1:x2]


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
    limite = _limite_bytes_saida()
    if e_png:
        for compresion in (3, 6, 9):
            correcto, datos = cv2.imencode(
                ".png",
                imaxe,
                [cv2.IMWRITE_PNG_COMPRESSION, compresion],
            )
            if correcto and len(datos) <= limite:
                return datos.tobytes(), "png"
        return None
    else:
        # Selecciónase sempre a maior calidade que caiba no límite. A maioría
        # dos recortes entran a 97; a redución gradual só se emprega cando a
        # rotación do lenzo completo aumenta o tamaño do JPEG.
        for calidade in (97, 96, 95, 94, 93, 92):
            parametros = [cv2.IMWRITE_JPEG_QUALITY, calidade]
            if hasattr(cv2, "IMWRITE_JPEG_SAMPLING_FACTOR_444"):
                parametros.extend(
                    [
                        cv2.IMWRITE_JPEG_SAMPLING_FACTOR,
                        cv2.IMWRITE_JPEG_SAMPLING_FACTOR_444,
                    ]
                )
            correcto, datos = cv2.imencode(".jpg", imaxe, parametros)
            if correcto and len(datos) <= limite:
                return datos.tobytes(), "jpg"
        return None
