import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

from app.main import app


def campo(content=None, confidence=0.95, value_array=None):
    return SimpleNamespace(
        content=content,
        confidence=confidence,
        value_array=value_array,
    )


def fila(**columnas):
    return SimpleNamespace(value_object=columnas)


class TestRamasExtraccion(unittest.TestCase):
    def setUp(self):
        self.azure = MagicMock()
        app.state.doc_intel_client = self.azure
        self.client = TestClient(app)

    def responder_con(self, fields):
        documento = SimpleNamespace(fields=fields)
        resultado = SimpleNamespace(documents=[documento])
        self.azure.begin_analyze_document.return_value.result.return_value = resultado

    def enviar(self, tipo="image/jpeg"):
        return self.client.post(
            "/extraccion/",
            files={"file": ("informe", b"bytes de proba", tipo)},
        )

    def test_control_coherente_conserva_a_data_e_o_discordante_corríxese(self):
        for data_control, data_esperada in (
            ("10 ENE CONTROL", "2026-01-10"),
            ("09 ENE CONTROL", "2026-01-10"),
        ):
            with self.subTest(data_control=data_control):
                self.responder_con({
                    "fecha visita": campo("01/01/2026"),
                    "prox visit": campo("10/01/2026"),
                    "DOSE": campo(value_array=[fila(LUNES=campo(data_control))]),
                })
                resposta = self.enviar()
                self.assertEqual(resposta.status_code, 200)
                self.assertEqual(resposta.json()["calendario"][0]["data"], data_esperada)
                self.assertEqual(resposta.json()["calendario"][0]["dia"], 10)

    def test_campos_opcionais_ausentes_e_ruv_incompleto_non_bloquean(self):
        filas_ruv = [
            SimpleNamespace(value_object=None),
            fila(Comentarios=campo("sen data nin INR")),
            fila(Descoñecido=campo("ignórase"), INR=None),
            fila(
                Fecha=campo("2026-01-01"),
                APTT=campo("INHIXA"),
                **{"Dosis iny": campo("4000 UI")},
            ),
        ]
        self.responder_con({
            "campo auxiliar": campo("valor"),
            "DOSE": campo(value_array=[
                SimpleNamespace(value_object=None),
                fila(LUNES=None, MARTES=campo("texto ilexible"), MIERCOLES=campo("03 ENE 1/2")),
            ]),
            "RUV": campo(value_array=filas_ruv),
        })

        resposta = self.enviar()

        self.assertEqual(resposta.status_code, 200)
        datos = resposta.json()
        self.assertIsNone(datos["cabeceira"]["dataInforme"])
        self.assertIsNone(datos["cabeceira"]["inr"])
        self.assertEqual(len(datos["calendario"]), 1)
        self.assertEqual(len(datos["historico"]), 1)
        self.assertEqual(datos["historico"][0]["apttInyectable"], "INHIXA")
        self.assertEqual(datos["historico"][0]["doseInyectable"], "4000 UI")

    def test_tipos_admitidos_chegan_ao_ocr(self):
        for tipo in (
            "image/jpeg",
            "image/png",
            "image/heic",
            "image/heif",
            "application/pdf",
            "application/octet-stream",
        ):
            with self.subTest(tipo=tipo):
                self.azure.reset_mock()
                self.azure.begin_analyze_document.return_value.result.return_value = SimpleNamespace(
                    documents=[]
                )
                resposta = self.enviar(tipo)
                self.assertEqual(resposta.status_code, 400)
                argumentos = self.azure.begin_analyze_document.call_args.kwargs
                self.assertEqual(argumentos["content_type"], "application/octet-stream")
                self.assertEqual(argumentos["locale"], "es-ES")

    def test_ficheiro_obrigatorio(self):
        resposta = self.client.post("/extraccion/")
        self.assertEqual(resposta.status_code, 422)


if __name__ == "__main__":
    unittest.main()
