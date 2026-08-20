import unittest
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from app.main import app


class TestNotificacionsP2P(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.datos = {
            "token_destino": "token-fcm-destino",
            "payload": '{"ciphertext":"abc"}',
            "tipo_aviso": "TOMA_CONFIRMADA",
        }

    @patch("app.routers.notificar.messaging.send", return_value="mensaxe-123")
    @patch("app.routers.notificar.messaging.Notification")
    @patch("app.routers.notificar.messaging.Message")
    def test_envio_dos_catro_avisos_co_texto_correcto(
        self, message_mock, notification_mock, send_mock
    ):
        textos = {
            "TOMA_CONFIRMADA": ("Toma confirmada", "A persoa supervisada confirmou a toma."),
            "NOVO_INFORME": ("Novo informe", "Actualizouse a folla de tratamento."),
            "TOMA_PENDENTE": ("Hora da toma", "Hai unha toma pendente de confirmar."),
            "TOMA_ESQUECIDA": ("Toma sen confirmar", "A toma segue sen confirmarse."),
        }
        mensaxe = MagicMock()
        message_mock.return_value = mensaxe

        for tipo, (titulo, corpo) in textos.items():
            with self.subTest(tipo=tipo):
                notification_mock.reset_mock()
                message_mock.reset_mock()
                resposta = self.client.post(
                    "/notificar/enviar", json={**self.datos, "tipo_aviso": tipo}
                )
                self.assertEqual(resposta.status_code, 200)
                self.assertEqual(resposta.json(), {"success": True, "message_id": "mensaxe-123"})
                notification_mock.assert_called_once_with(title=titulo, body=corpo)
                argumentos = message_mock.call_args.kwargs
                self.assertEqual(argumentos["token"], "token-fcm-destino")
                self.assertEqual(argumentos["data"]["payload"], self.datos["payload"])
                self.assertEqual(argumentos["data"]["tipo_aviso"], tipo)
                self.assertIs(argumentos["notification"], notification_mock.return_value)
                send_mock.assert_called_with(mensaxe)

    @patch("app.routers.notificar.messaging.send", return_value="mensaxe-456")
    @patch("app.routers.notificar.messaging.Message")
    def test_aviso_descoñecido_envíase_sen_notificacion_visual(self, message_mock, _send_mock):
        resposta = self.client.post(
            "/notificar/enviar", json={**self.datos, "tipo_aviso": "OUTRO"}
        )

        self.assertEqual(resposta.status_code, 200)
        self.assertIsNone(message_mock.call_args.kwargs["notification"])

    @patch("app.routers.notificar.messaging.send", side_effect=RuntimeError("FCM non dispoñible"))
    def test_erro_de_firebase_convírtese_en_500(self, _send_mock):
        resposta = self.client.post("/notificar/enviar", json=self.datos)

        self.assertEqual(resposta.status_code, 500)
        self.assertIn("FCM non dispoñible", resposta.json()["detail"])

    def test_peticion_incompleta_devolve_422(self):
        resposta = self.client.post(
            "/notificar/enviar", json={"token_destino": "token", "tipo_aviso": "NOVO_INFORME"}
        )
        self.assertEqual(resposta.status_code, 422)


if __name__ == "__main__":
    unittest.main()
