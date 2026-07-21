import os
import unittest
from unittest.mock import MagicMock, patch

import cv2
import numpy as np
from fastapi.testclient import TestClient

from app.internal.preprocesamento import ResultadoPreprocesamento, preprocesar_documento
from server.app.main import app


def _codificar(imaxe: np.ndarray, extension: str = ".png") -> bytes:
    correcto, datos = cv2.imencode(extension, imaxe)
    if not correcto:
        raise RuntimeError("Non se puido preparar a imaxe de proba")
    return datos.tobytes()


def _crear_folla(ancho: int = 560, alto: int = 760, con_bordo: bool = True) -> np.ndarray:
    imaxe = np.full((alto, ancho, 3), 255, dtype=np.uint8)
    if con_bordo:
        cv2.rectangle(imaxe, (12, 12), (ancho - 13, alto - 13), (20, 20, 20), 5)
    for y in range(100, alto - 70, 65):
        cv2.line(imaxe, (35, y), (ancho - 35, y), (40, 40, 40), 3)
    for x in (100, 210, 335, 450):
        cv2.line(imaxe, (x, 100), (x, alto - 75), (70, 70, 70), 2)
    cv2.putText(
        imaxe,
        "PAUTA DE TRATAMENTO",
        (45, 65),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.75,
        (20, 20, 20),
        2,
        cv2.LINE_AA,
    )
    return imaxe


def _rotar(imaxe: np.ndarray, angulo: float) -> np.ndarray:
    alto, ancho = imaxe.shape[:2]
    centro = (ancho / 2.0, alto / 2.0)
    matriz = cv2.getRotationMatrix2D(centro, angulo, 1.0)
    coseno = abs(matriz[0, 0])
    seno = abs(matriz[0, 1])
    novo_ancho = int(np.ceil(alto * seno + ancho * coseno))
    novo_alto = int(np.ceil(alto * coseno + ancho * seno))
    matriz[0, 2] += novo_ancho / 2.0 - centro[0]
    matriz[1, 2] += novo_alto / 2.0 - centro[1]
    return cv2.warpAffine(
        imaxe,
        matriz,
        (novo_ancho, novo_alto),
        flags=cv2.INTER_CUBIC,
        borderValue=(75, 75, 75),
    )


class TestPreprocesamento(unittest.TestCase):
    def test_pdf_pasa_byte_a_byte_sen_cambios(self):
        pdf = b"%PDF-1.7\ncontido de proba"

        resultado = preprocesar_documento(pdf, "application/octet-stream", activado=True)

        self.assertFalse(resultado.aplicado)
        self.assertEqual(resultado.motivo, "pdf")
        self.assertIs(resultado.contido, pdf)

    def test_heif_non_se_modifica(self):
        heif = b"\x00\x00\x00\x18ftypheic" + b"datos"

        resultado = preprocesar_documento(heif, "image/heic", activado=True)

        self.assertFalse(resultado.aplicado)
        self.assertEqual(resultado.contido, heif)

    def test_bytes_invalidos_non_bloquean_o_ocr(self):
        entrada = b"non e unha imaxe"

        resultado = preprocesar_documento(entrada, "image/jpeg", activado=True)

        self.assertFalse(resultado.aplicado)
        self.assertEqual(resultado.contido, entrada)

    def test_unha_imaxe_recta_non_se_recomprime(self):
        entrada = _codificar(_crear_folla())

        resultado = preprocesar_documento(entrada, "image/png", activado=True)

        self.assertFalse(resultado.aplicado)
        self.assertEqual(resultado.contido, entrada)

    def test_corrixe_unha_inclinacion_moderada(self):
        entrada = _codificar(_rotar(_crear_folla(), 7.0))

        resultado = preprocesar_documento(entrada, "image/png", activado=True)

        self.assertTrue(resultado.aplicado)
        self.assertIn(resultado.metodo, {"perspectiva", "inclinacion"})
        self.assertGreater(resultado.confianza, 0.7)
        self.assertNotEqual(resultado.contido, entrada)

        segunda_pasada = preprocesar_documento(
            resultado.contido,
            "image/png",
            activado=True,
        )
        self.assertFalse(segunda_pasada.aplicado)

    def test_corrixe_perspectiva_cando_detecta_os_catro_bordos(self):
        folla = _crear_folla(500, 700)
        orixe = np.float32([[0, 0], [499, 0], [499, 699], [0, 699]])
        destino = np.float32([[145, 75], [655, 125], [620, 820], [90, 765]])
        matriz = cv2.getPerspectiveTransform(orixe, destino)
        deformada = cv2.warpPerspective(
            folla,
            matriz,
            (760, 900),
            flags=cv2.INTER_CUBIC,
            borderValue=(65, 65, 65),
        )
        entrada = _codificar(deformada)

        resultado = preprocesar_documento(entrada, "image/png", activado=True)

        self.assertTrue(resultado.aplicado)
        self.assertEqual(resultado.metodo, "perspectiva")

    def test_sen_catro_bordos_non_inventa_un_recorte(self):
        sen_bordo = _crear_folla(con_bordo=False)
        inclinada = _rotar(sen_bordo, -6.0)
        recortada = inclinada[:, 75:-75]
        entrada = _codificar(recortada)

        resultado = preprocesar_documento(entrada, "image/png", activado=True)

        self.assertTrue(resultado.aplicado)
        self.assertEqual(resultado.metodo, "inclinacion")
        self.assertGreaterEqual(resultado.dimensions_saida[0], resultado.dimensions_orixinais[0])
        self.assertGreaterEqual(resultado.dimensions_saida[1], resultado.dimensions_orixinais[1])

        segunda_pasada = preprocesar_documento(
            resultado.contido,
            "image/png",
            activado=True,
        )
        self.assertFalse(segunda_pasada.aplicado)
        self.assertEqual(segunda_pasada.contido, resultado.contido)

    def test_non_confunde_un_panel_interno_co_bordo_do_papel(self):
        panel = _crear_folla(600, 760)
        panel = (panel.astype(np.float32) * 0.92).astype(np.uint8)
        orixe = np.float32([[0, 0], [599, 0], [599, 759], [0, 759]])
        destino = np.float32([[120, 95], [718, 147], [650, 905], [54, 853]])
        matriz = cv2.getPerspectiveTransform(orixe, destino)
        imaxe = cv2.warpPerspective(
            panel,
            matriz,
            (800, 1000),
            borderValue=(255, 255, 255),
        )
        entrada = _codificar(imaxe)

        resultado = preprocesar_documento(entrada, "image/png", activado=True)

        self.assertNotEqual(resultado.metodo, "perspectiva")
        if resultado.aplicado:
            self.assertEqual(resultado.metodo, "inclinacion")
            self.assertGreaterEqual(resultado.dimensions_saida[0], resultado.dimensions_orixinais[0])
            self.assertGreaterEqual(resultado.dimensions_saida[1], resultado.dimensions_orixinais[1])

    def test_conserva_o_orixinal_se_a_saida_supera_o_limite(self):
        inclinada = _rotar(_crear_folla(), 7.0)
        correcto, datos = cv2.imencode(
            ".jpg",
            inclinada,
            [cv2.IMWRITE_JPEG_QUALITY, 60],
        )
        self.assertTrue(correcto)
        entrada = datos.tobytes()

        with patch.dict(os.environ, {"PREPROCESS_MAX_BYTES": "90000"}):
            resultado = preprocesar_documento(entrada, "image/jpeg", activado=True)

        self.assertFalse(resultado.aplicado)
        self.assertEqual(resultado.contido, entrada)
        self.assertLessEqual(len(resultado.contido), 90000)

    def test_non_expande_a_rotacion_por_riba_do_limite(self):
        sen_bordo = _crear_folla(con_bordo=False)
        inclinada = _rotar(sen_bordo, -6.0)[:, 75:-75]
        entrada = _codificar(inclinada)

        with patch("app.internal.preprocesamento.MAX_LADO_AZURE", 820):
            resultado = preprocesar_documento(entrada, "image/png", activado=True)

        self.assertFalse(resultado.aplicado)
        self.assertEqual(resultado.contido, entrada)
        self.assertEqual(resultado.motivo, "saida_supera_limite_de_dimensions")

    def test_podese_desactivar_sen_modificar_a_entrada(self):
        entrada = _codificar(_rotar(_crear_folla(), 8.0))

        resultado = preprocesar_documento(entrada, "image/png", activado=False)

        self.assertFalse(resultado.aplicado)
        self.assertEqual(resultado.motivo, "desactivado")
        self.assertEqual(resultado.contido, entrada)


class TestIntegracionPreprocesamentoAPI(unittest.TestCase):
    def setUp(self):
        self.cliente_azure = MagicMock()
        app.state.doc_intel_client = self.cliente_azure
        self.cliente = TestClient(app)

    @patch("app.routers.extraccion.preprocesar_documento")
    def test_a_api_envia_a_azure_a_imaxe_preprocesada(self, preprocesar_mock):
        preprocesar_mock.return_value = ResultadoPreprocesamento(
            contido=b"imaxe procesada",
            aplicado=True,
            metodo="inclinacion",
            motivo="proba",
        )
        resultado_azure = MagicMock()
        resultado_azure.documents = []
        self.cliente_azure.begin_analyze_document.return_value.result.return_value = resultado_azure

        resposta = self.cliente.post(
            "/extraccion/",
            files={"file": ("informe.jpg", b"imaxe orixinal", "image/jpeg")},
        )

        self.assertEqual(resposta.status_code, 400)
        chamada = self.cliente_azure.begin_analyze_document.call_args
        self.assertEqual(chamada.kwargs["body"], b"imaxe procesada")


if __name__ == "__main__":
    unittest.main()
