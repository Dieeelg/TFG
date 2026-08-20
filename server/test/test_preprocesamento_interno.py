import unittest
from unittest.mock import patch

import cv2
import numpy as np

from app.internal import preprocesamento as p


def codificar_imaxe(ancho=400, alto=500):
    imaxe = np.full((alto, ancho, 3), 255, dtype=np.uint8)
    correcto, datos = cv2.imencode(".png", imaxe)
    if not correcto:
        raise RuntimeError("Non se puido crear a imaxe de proba")
    return imaxe, datos.tobytes()


class TestDefensasPreprocesamento(unittest.TestCase):
    def test_reducion_da_imaxe_para_a_deteccion(self):
        imaxe = np.zeros((2000, 1000, 3), dtype=np.uint8)
        reducida, escala = p._preparar_deteccion(imaxe)

        self.assertAlmostEqual(escala, 0.8)
        self.assertEqual(reducida.shape[:2], (1600, 800))

    def test_sen_deteccion_fiable_conserva_o_orixinal(self):
        _imaxe, entrada = codificar_imaxe()
        cuadrilatero = np.float32([[20, 20], [380, 20], [380, 480], [20, 480]])

        with (
            patch.object(p, "_buscar_folla", return_value=(cuadrilatero, 0.9)),
            patch.object(p, "_buscar_folla_clara", return_value=(cuadrilatero, 0.85)),
            patch.object(p, "_corrixir_perspectiva", return_value=None),
            patch.object(p, "_estimar_inclinacion", return_value=None),
        ):
            resultado = p.preprocesar_documento(entrada, "image/png", activado=True)

        self.assertFalse(resultado.aplicado)
        self.assertEqual(resultado.motivo, "deteccion_sen_confianza")
        self.assertEqual(resultado.contido, entrada)

    def test_fallo_da_perspectiva_parcial_e_da_codificacion_conserva_o_orixinal(self):
        imaxe, entrada = codificar_imaxe()
        cuadrilatero = np.float32([[20, 20], [380, 20], [380, 480], [20, 480]])
        puntos_linas = np.float32([[40, 100], [350, 180], [60, 250], [360, 330]])

        with (
            patch.object(p, "_buscar_folla", return_value=None),
            patch.object(p, "_buscar_folla_clara", return_value=None),
            patch.object(p, "_estimar_inclinacion", return_value=(15.0, 0.9, puntos_linas)),
            patch.object(
                p,
                "_buscar_folla_con_bordos_parciais",
                return_value=(cuadrilatero, 0.85),
            ),
            patch.object(p, "_corrixir_perspectiva", return_value=None),
            patch.object(p, "_rotar_e_recortar_recheo", return_value=imaxe),
            patch.object(p, "_codificar", return_value=None),
        ):
            resultado = p.preprocesar_documento(entrada, "image/png", activado=True)

        self.assertFalse(resultado.aplicado)
        self.assertEqual(resultado.motivo, "erro_de_codificacion")

    def test_helpers_de_xeometria_en_casos_degenerados(self):
        gris = np.zeros((20, 20), dtype=np.uint8)
        punto = np.array([3.0, 4.0], dtype=np.float32)
        self.assertEqual(p._contraste_segmento(gris, punto, punto), 0.0)

        paralela_a = {"normal": np.array([1.0, 0.0]), "distancia": 1.0}
        paralela_b = {"normal": np.array([1.0, 0.0]), "distancia": 2.0}
        self.assertIsNone(p._interseccion_linhas(paralela_a, paralela_b))

        puntos_repetidos = np.float32([[0, 0], [0, 0], [10, 10], [0, 10]])
        self.assertEqual(p._angulos_interiores(puntos_repetidos), [0.0] * 4)
        self.assertEqual(p._contrastes_dos_lados(gris, puntos_repetidos), 0.0)

    def test_perspectiva_rexeita_saidas_invalidas(self):
        imaxe = np.zeros((500, 500, 3), dtype=np.uint8)
        entrada = b"orixinal"
        puntos = np.float32([[50, 50], [450, 50], [450, 450], [50, 450]])

        puntos_pequenos = np.float32([[200, 200], [300, 200], [300, 300], [200, 300]])
        with patch.object(p, "_normalizar_angulo", return_value=2.0):
            self.assertIsNone(
                p._corrixir_perspectiva(
                    entrada, imaxe, puntos_pequenos, 0.9, "image/png"
                )
            )

        with (
            patch.object(p, "_normalizar_angulo", return_value=2.0),
            patch.object(p, "MAX_LADO_AZURE", 200),
        ):
            self.assertIsNone(
                p._corrixir_perspectiva(entrada, imaxe, puntos, 0.9, "image/png")
            )

        pequena = np.zeros((200, 200, 3), dtype=np.uint8)
        with (
            patch.object(p, "_lonxitudes_lados", return_value=[300, 300, 300, 300]),
            patch.object(p, "_normalizar_angulo", return_value=2.0),
            patch.object(p.np.linalg, "norm", return_value=300.0),
        ):
            self.assertIsNone(
                p._corrixir_perspectiva(entrada, pequena, puntos, 0.9, "image/png")
            )

    def test_estimacion_rexeita_linas_insuficientes_ou_incoherentes(self):
        bordos = np.zeros((1000, 1000), dtype=np.uint8)
        with patch.object(p.cv2, "HoughLinesP", return_value=None):
            self.assertIsNone(p._estimar_inclinacion(bordos))

        poucas = np.array([[[0, 0, 100, 0]], [[0, 0, 200, 200]]], dtype=np.int32)
        with patch.object(p.cv2, "HoughLinesP", return_value=poucas):
            self.assertIsNone(p._estimar_inclinacion(bordos))

        cinco = np.array(
            [[[0, y, 500, y]] for y in (10, 30, 50, 70, 90)],
            dtype=np.int32,
        )
        with (
            patch.object(p.cv2, "HoughLinesP", return_value=cinco),
            patch.object(p, "_mediana_ponderada", side_effect=[0.0, 2.0]),
        ):
            self.assertIsNone(p._estimar_inclinacion(bordos))

    def test_rotacion_sen_pixeles_validos_e_sen_recorte(self):
        imaxe = np.zeros((100, 100, 3), dtype=np.uint8)
        puntos = np.float32([[20, 20], [80, 80]])

        with patch.object(
            p.cv2,
            "warpAffine",
            side_effect=[imaxe.copy(), np.zeros((123, 123), dtype=np.uint8)],
        ):
            resultado = p._rotar_e_recortar_recheo(imaxe, 15.0, puntos)
        self.assertEqual(resultado.shape, imaxe.shape)

        mascara_esparsa = np.zeros((123, 123), dtype=np.uint8)
        mascara_esparsa[60, 60] = 255
        with patch.object(
            p.cv2,
            "warpAffine",
            side_effect=[imaxe.copy(), mascara_esparsa],
        ):
            resultado = p._rotar_e_recortar_recheo(imaxe, 15.0, puntos)
        self.assertEqual(resultado.shape, imaxe.shape)

    def test_codificacion_png_pode_fallar_sen_lanzar_excepcion(self):
        imaxe = np.zeros((200, 200, 3), dtype=np.uint8)
        with patch.object(
            p.cv2,
            "imencode",
            return_value=(False, np.array([], dtype=np.uint8)),
        ):
            self.assertIsNone(p._codificar(imaxe, "image/png", b"\x89PNG\r\n\x1a\n"))


if __name__ == "__main__":
    unittest.main()
