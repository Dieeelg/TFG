import unittest
import os
import sys
from datetime import datetime
from fastapi.testclient import TestClient
from pycparser.ply.yacc import resultlimit
from unittest.mock import MagicMock, patch, Mock
from azure.core.exceptions import HttpResponseError
from server.app.main import app

class TestSintromAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """
        Creación do escenario de probas
        """
        # Creamos unha variable de controno para que non se intente conctar mediante o key vault
        cls.env_patcher = patch.dict('os.environ', {"DOC_INTEL_KEY": "clave_de_test"})
        # Aplica a variable de contorno para as probas
        cls.env_patcher.start()

        # Creamos o cliente que simula o cliente de Azure
        cls.mock_azure_client = MagicMock()
        # Inxecta o mock no estado da app
        app.state.doc_intel_client = cls.mock_azure_client

        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls):
        cls.env_patcher.stop()

    def setUp(self):
        """
         Antes de cada test borramos a memoria do cliente simulado para que todas as probas sexan independetes
        """
        self.mock_azure_client.reset_mock()

        # Eliminamos os erros de test anteriores
        self.mock_azure_client.begin_analyze_document.side_effect = None

    def test_endpoint_health(self):
        """
        Comprobación de que o endpoint /health funciona correctamente e devolve o que ten que devolver
        """
        resposta = self.client.get("/health")
        self.assertEqual(resposta.status_code, 200)
        self.assertEqual(resposta.json()["status"], "OK")

    def test_iniciar_extraccion_erro_tipo_ficheiro(self):
        """
        Se se intenta subir un documento que non é válido como un .txt ou calquera outro diferente a
        JPEG, PNG, HEIC ou PDF. Desta maneira comprobamos que non acepta arquivos qu non sexan os antes
        mencionados e que devolve o erro correcto: 400 Tipo de ficheiro non soportado
        """
        # Creamos un ficheiro falso con un formato que non se acepta na API
        files = {'file': ('test.txt', b'Contido de proba para o txt', 'text/plain')}
        # Facemos a peticion con ese ficheiro
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 400)
        self.assertIn("Tipo de ficheiro non soportado:", resposta.json()["detail"])

    def test_iniciar_extraccion_erro_confianza_baixa(self):
        """
        Comprobación de que ser recibe uns resultados cunha confianza baixa descarta ditos resultados
        e da erro o 400.
        """
        mock_result = MagicMock()  # Simula o AnalyzeResult que nos devolvería a Azure ao analizar un documento
        mock_doc = MagicMock()  # Simula o Document
        # Establecemos a confianza dese campo moi baixa, desta forma como é o unico campo
        # a confianza xeral vai a dar moi baixa e fora do noso limiar de descarte (<0.6)
        campo_confianza = MagicMock(confidence=0.1)  # Simula un campo dentro do Document

        # Agora metemos o campo dentro do Document
        mock_doc.fields.values.return_value = [campo_confianza]
        # E metenos o document dentro do AnalyzeResult
        mock_result.documents = [mock_doc]

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result
        """
        No codigo da nosa api temos isto:
        ocr_operation = client.begin_analyze_document(
            model_id=MODEL_ID,
            body=image_content,
            content_type="application/octet-stream"
        )

        result = ocr_operation.result()

        document = result.documents[0]

        A rquivalencia nos test co noso mock sería:
        * mock_azure_client.begin_analyze_document.return_value = ocr_operation
        * .result.return_value = result

        Conclusión: Aqui estamos indicando que o que ten que devolver se se fai esa chamada é eso mock_result, é
        dicir a simulación que fixemos de document
        """

        # Simulamos o arquivo que se vai a enviar
        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        # Enviamos a petición á API
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 400)
        self.assertIn("O documento non é lexible.", resposta.json()["detail"])

    def test_iniciar_extraccion_erro_result_baleiro(self):
        """
        Comprobamos que se a api non devolve ningún documento se lanza a excepción correspondente (400).
        """
        mock_result = MagicMock()
        mock_result.documents = []

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 400)
        self.assertIn("Non se detectou un documento válido na imaxe", resposta.json()["detail"])

    def test_iniciar_extraccion_exitosa(self):
        """
        Comprobación de que en caso de éxito:
        * A resposta é un 200 OK
        * Se limpan os datos correctamente
        """

        mock_result = MagicMock()
        mock_doc = MagicMock()

        # Simulamos unha resposta completa da API de azure
        mock_doc.fields = {
            "fecha visita": MagicMock(content="2018-03-27 10:38:02", confidence=0.806),
            "inr": MagicMock(content="2,8", confidence=0.946),
            "farmaco oral": Mock(content="Sintrom 4 mg", confidence=0.946),
            "dosis semanal": MagicMock(content="13,5 mg (1/2 día - DOM alternos 1/4)", confidence=0.857),
            "prox visit": MagicMock(content="jueves, 05/04/2018", confidence=0.822),
            "centro visita": MagicMock(content="C.S. VIVEIRO", confidence=0.946),
            "turno": MagicMock(content="Mañanas", confidence=0.857),
            "RUV": MagicMock(value_array=[MagicMock(value_object={  # Creamos unha fila ficticia do RUV
                "Fecha": MagicMock(content="2018-03-20"),
                "INR": MagicMock(content="4,5"),
                "Fármaco AVK": MagicMock(content="Sintrom 4 mg"),
                "Dosis": MagicMock(content="13,5 mg"),
                "Próx. Visita": MagicMock(content="27/03/2018"),
                "Comentarios": MagicMock(content="HOY NO TOME SINTROM")
            })
            ], confidence=0.857
            ),
            "DOSE": MagicMock(value_array=[MagicMock(value_object={
                "MARTES": MagicMock(content="27\nMAR 1/2"),
            })
            ], confidence=0.932
            ),
        }

        mock_result.documents = [mock_doc]

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 200)

        datos = resposta.json()

        cabeceira = datos["cabeceira"]
        self.assertEqual(cabeceira["dataInforme"], "2018-03-27")
        self.assertEqual(cabeceira["inr"], "2,8")
        self.assertEqual(cabeceira["farmaco"], "Sintrom 4 mg")
        self.assertEqual(cabeceira["doseSemanal"], "13,5 mg")
        self.assertEqual(cabeceira["proximaVisita"], "05/04/2018")
        self.assertEqual(cabeceira["centro"], "C.S. VIVEIRO")

        calendario = datos["calendario"]
        item_cal = calendario[0]
        self.assertEqual(item_cal["data"], "2018-03-27")
        self.assertEqual(item_cal["dia"], 27)
        self.assertEqual(item_cal["dose"], "1/2")
        self.assertEqual(item_cal["accion"], "TOMAR")
        self.assertEqual(item_cal["eControl"], False)
        self.assertEqual(item_cal["diaSemanaTexto"], "MARTES")

        ruv = datos["historico"]
        item_ruv = ruv[0]
        self.assertEqual(item_ruv["data"], "2018-03-20")
        self.assertEqual(item_ruv["inr"], "4,5")
        self.assertEqual(item_ruv["farmaco"], "Sintrom 4 mg")
        self.assertEqual(item_ruv["dose"], "13,5 mg")
        self.assertEqual(item_ruv["proximaVisita"], "27/03/2018")
        self.assertEqual(item_ruv["comentarios"], "HOY NO TOME SINTROM")

    def test_iniciar_extraccion_erro_taboa_dose_non_atopada(self):
        """
        Comprobación de que en caso de éxito:
        * A resposta é un 200 OK
        * Se limpan os datos correctamente
        """

        mock_result = MagicMock()
        mock_doc = MagicMock()

        # Simulamos unha resposta completa da API de azure
        mock_doc.fields = {
            "fecha visita": MagicMock(content="2018-03-27 10:38:02", confidence=0.806),
            "inr": MagicMock(content="2,8", confidence=0.946),
            "farmaco oral": Mock(content="Sintrom 4 mg", confidence=0.946),
            "dosis semanal": MagicMock(content="13,5 mg (1/2 día - DOM alternos 1/4)", confidence=0.857),
            "prox visit": MagicMock(content="jueves, 05/04/2018", confidence=0.822),
            "centro visita": MagicMock(content="C.S. VIVEIRO", confidence=0.946),
            "turno": MagicMock(content="Mañanas", confidence=0.857),
            "RUV": MagicMock(value_array=[MagicMock(value_object={  # Creamos unha fila ficticia do RUV
                "Fecha": MagicMock(content="2018-03-20"),
                "INR": MagicMock(content="4,5"),
                "Fármaco AVK": MagicMock(content="Sintrom 4 mg"),
                "Dosis": MagicMock(content="13,5 mg"),
                "Próx. Visita": MagicMock(content="27/03/2018"),
                "Comentarios": MagicMock(content="HOY NO TOME SINTROM")
            })
            ], confidence=0.857
            ),
            "DOSE": MagicMock(value_array=[], confidence=0.89
                              ),
        }

        mock_result.documents = [mock_doc]

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 400)
        self.assertIn("Táboa de dose non atopada", resposta.json()["detail"])

    def test_iniciar_extraccion_inr_fora_de_rango(self):
        """
        Comprobación de que se azure extrae un valor de INR que é imposible se devolve un erro 400
        """
        mock_result = MagicMock()
        mock_doc = MagicMock()

        # Simulamos unha resposta completa da API de azure
        mock_doc.fields = {
            "fecha visita": MagicMock(content="2018-03-27 10:38:02", confidence=0.806),
            "inr": MagicMock(content="15", confidence=0.946),
            "farmaco oral": Mock(content="Sintrom 4 mg", confidence=0.946),
            "dosis semanal": MagicMock(content="13,5 mg (1/2 día - DOM alternos 1/4)", confidence=0.857),
            "prox visit": MagicMock(content="jueves, 05/04/2018", confidence=0.822),
            "centro visita": MagicMock(content="C.S. VIVEIRO", confidence=0.946),
            "turno": MagicMock(content="Mañanas", confidence=0.857),
            "RUV": MagicMock(value_array=[MagicMock(value_object={  # Creamos unha fila ficticia do RUV
                "Fecha": MagicMock(content="2018-03-20"),
                "INR": MagicMock(content="4,5"),
                "Fármaco AVK": MagicMock(content="Sintrom 4 mg"),
                "Dosis": MagicMock(content="13,5 mg"),
                "Próx. Visita": MagicMock(content="27/03/2018"),
                "Comentarios": MagicMock(content="HOY NO TOME SINTROM")
            })
            ], confidence=0.857
            ),
            "DOSE": MagicMock(value_array=[MagicMock(value_object={
                "MARTES": MagicMock(content="27\nMAR 1/2"),
            })
            ], confidence=0.932
            ),
        }

        mock_result.documents = [mock_doc]

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 400)
        self.assertIn("O valor de INR detectado", resposta.json()["detail"])

    def test_iniciar_extraccion_inr_confianza_baixa(self):
        """
        Comprobación de que no caso de que o INR teña unha confianza baixa (<0.8) se devolva o erro 400
        """
        mock_result = MagicMock()
        mock_doc = MagicMock()

        # Simulamos unha resposta completa da API de azure
        mock_doc.fields = {
            "fecha visita": MagicMock(content="2018-03-27 10:38:02", confidence=0.806),
            "inr": MagicMock(content="1,5", confidence=0.50),
            "farmaco oral": Mock(content="Sintrom 4 mg", confidence=0.946),
            "dosis semanal": MagicMock(content="13,5 mg (1/2 día - DOM alternos 1/4)", confidence=0.857),
            "prox visit": MagicMock(content="jueves, 05/04/2018", confidence=0.822),
            "centro visita": MagicMock(content="C.S. VIVEIRO", confidence=0.946),
            "turno": MagicMock(content="Mañanas", confidence=0.857),
            "RUV": MagicMock(value_array=[MagicMock(value_object={  # Creamos unha fila ficticia do RUV
                "Fecha": MagicMock(content="2018-03-20"),
                "INR": MagicMock(content="4,5"),
                "Fármaco AVK": MagicMock(content="Sintrom 4 mg"),
                "Dosis": MagicMock(content="13,5 mg"),
                "Próx. Visita": MagicMock(content="27/03/2018"),
                "Comentarios": MagicMock(content="HOY NO TOME SINTROM")
            })
            ], confidence=0.857
            ),
            "DOSE": MagicMock(value_array=[MagicMock(value_object={
                "MARTES": MagicMock(content="27\nMAR 1/2"),
            })
            ], confidence=0.932
            ),
        }

        mock_result.documents = [mock_doc]

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 400)
        self.assertIn("Non podemos asegurar a precisión do valor do INR.", resposta.json()["detail"])

    def test_iniciar_extraccion_inr_baleiro(self):
        """
        Comprobación de que no caso de que o INR teña unha confianza baixa (<0.8) se devolva o erro 400
        """
        mock_result = MagicMock()
        mock_doc = MagicMock()

        mock_doc.fields = {
            "fecha visita": MagicMock(content="2018-03-27 10:38:02", confidence=0.806),
            "inr": MagicMock(content="sdada", confidence=0.8),
            "farmaco oral": Mock(content="Sintrom 4 mg", confidence=0.946),
            "dosis semanal": MagicMock(content="13,5 mg (1/2 día - DOM alternos 1/4)", confidence=0.857),
            "prox visit": MagicMock(content="jueves, 05/04/2018", confidence=0.822),
            "centro visita": MagicMock(content="C.S. VIVEIRO", confidence=0.946),
            "turno": MagicMock(content="Mañanas", confidence=0.857),
            "RUV": MagicMock(value_array=[MagicMock(value_object={  # Creamos unha fila ficticia do RUV
                "Fecha": MagicMock(content="2018-03-20"),
                "INR": MagicMock(content="4,5"),
                "Fármaco AVK": MagicMock(content="Sintrom 4 mg"),
                "Dosis": MagicMock(content="13,5 mg"),
                "Próx. Visita": MagicMock(content="27/03/2018"),
                "Comentarios": MagicMock(content="HOY NO TOME SINTROM")
            })
            ], confidence=0.857
            ),
            "DOSE": MagicMock(value_array=[MagicMock(value_object={
                "MARTES": MagicMock(content="27\nMAR 1/2"),
            })
            ], confidence=0.932
            ),
        }

        mock_result.documents = [mock_doc]

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 400)
        self.assertIn("Erro co INR. Revisa que sexa lexible na imaxe", resposta.json()["detail"])

    """def test_iniciar_extraccion_taboa_dose_confianza_baixa(self):
        "Comprobamos que se azure ten pouca confianza na táboa da dose (<0.8) se devolva o erro 400."
        mock_result = MagicMock()
        mock_doc = MagicMock()

        mock_doc.fields = {
            "fecha visita": MagicMock(content="2018-03-27 10:38:02", confidence=0.806),
            "inr": MagicMock(content="2.5", confidence=0.8),
            "farmaco oral": Mock(content="Sintrom 4 mg", confidence=0.946),
            "dosis semanal": MagicMock(content="13,5 mg (1/2 día - DOM alternos 1/4)", confidence=0.857),
            "prox visit": MagicMock(content="jueves, 05/04/2018", confidence=0.822),
            "centro visita": MagicMock(content="C.S. VIVEIRO", confidence=0.946),
            "turno": MagicMock(content="Mañanas", confidence=0.857),
            "RUV": MagicMock(value_array=[MagicMock(value_object={  # Creamos unha fila ficticia do RUV
                "Fecha": MagicMock(content="2018-03-20"),
                "INR": MagicMock(content="4,5"),
                "Fármaco AVK": MagicMock(content="Sintrom 4 mg"),
                "Dosis": MagicMock(content="13,5 mg"),
                "Próx. Visita": MagicMock(content="27/03/2018"),
                "Comentarios": MagicMock(content="HOY NO TOME SINTROM")
            })
            ], confidence=0.857
            ),
            "DOSE": MagicMock(value_array=[MagicMock(value_object={
                "MARTES": MagicMock(content="27\nMAR 1/2"),
            })
            ], confidence=0.5
            ),
        }

        mock_result.documents = [mock_doc]

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 400)
        self.assertIn("Non podemos asegurar a precisión da táboa de doses", resposta.json()["detail"])"""

    def test_iniciar_extraccion_erro_cronoloxico(self):
        """
        Comprobación de que cando se extrae unha data de proxima visita anterior a data do informe se devolve o erro 400.
        """
        mock_result = MagicMock()
        mock_doc = MagicMock()

        mock_doc.fields = {
            "fecha visita": MagicMock(content="2019-03-27 10:38:02", confidence=0.806),
            "inr": MagicMock(content="2.5", confidence=0.8),
            "farmaco oral": Mock(content="Sintrom 4 mg", confidence=0.946),
            "dosis semanal": MagicMock(content="13,5 mg (1/2 día - DOM alternos 1/4)", confidence=0.857),
            "prox visit": MagicMock(content="jueves, 05/04/2018", confidence=0.822),
            "centro visita": MagicMock(content="C.S. VIVEIRO", confidence=0.946),
            "turno": MagicMock(content="Mañanas", confidence=0.857),
            "RUV": MagicMock(value_array=[MagicMock(value_object={  # Creamos unha fila ficticia do RUV
                "Fecha": MagicMock(content="2018-03-20"),
                "INR": MagicMock(content="4,5"),
                "Fármaco AVK": MagicMock(content="Sintrom 4 mg"),
                "Dosis": MagicMock(content="13,5 mg"),
                "Próx. Visita": MagicMock(content="27/03/2018"),
                "Comentarios": MagicMock(content="HOY NO TOME SINTROM")
            })
            ], confidence=0.857
            ),
            "DOSE": MagicMock(value_array=[MagicMock(value_object={
                "MARTES": MagicMock(content="27\nMAR 1/2"),
            })
            ], confidence=0.9
            ),
        }

        mock_result.documents = [mock_doc]

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 400)
        self.assertIn("A data de proxima visita parece incorrecta", resposta.json()["detail"])

    def test_iniciar_extraccion_erro_azure(self):
        """
        Comprobamos que no caso de que haxa un erro con azure se devolva 502 e non 500.
        """
        self.mock_azure_client.begin_analyze_document.side_effect = HttpResponseError

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 502)
        self.assertIn("Erro ao comunicarse co servizo de análise de documentos de Azure", resposta.json()["detail"])

    def test_iniciar_extraccion_erro_interno_servidor(self):
        """
        Comprobación de que se ocorre un erro inesperado durante a execución do endpoint /extraccion/ se
        devovle o erro correspondente (500 Internal Server Error)
        """
        self.mock_azure_client.begin_analyze_document.side_effect = Exception

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 500)
        self.assertIn("Erro interno do servidor", resposta.json()["detail"])

    def test_iniciar_extraccion_ruv_baleiro(self):
        """
        Comprobación de que a pesar de que o resumo das ultimas visitas estea baleiro o resto segue fncionando.
        """
        """
                Comprobación de que en caso de éxito:
                * A resposta é un 200 OK
                * Se limpan os datos correctamente
                """

        mock_result = MagicMock()
        mock_doc = MagicMock()

        # Simulamos unha resposta completa da API de azure
        mock_doc.fields = {
            "fecha visita": MagicMock(content="2018-03-27 10:38:02", confidence=0.806),
            "inr": MagicMock(content="2,8", confidence=0.946),
            "farmaco oral": Mock(content="Sintrom 4 mg", confidence=0.946),
            "dosis semanal": MagicMock(content="13,5 mg (1/2 día - DOM alternos 1/4)", confidence=0.857),
            "prox visit": MagicMock(content="jueves, 05/04/2018", confidence=0.822),
            "centro visita": MagicMock(content="C.S. VIVEIRO", confidence=0.946),
            "turno": MagicMock(content="Mañanas", confidence=0.857),
            "RUV": MagicMock(value_array=[], confidence=0.857
                             ),
            "DOSE": MagicMock(value_array=[MagicMock(value_object={
                "MARTES": MagicMock(content="27\nMAR 1/2"),
            })
            ], confidence=0.932
            ),
        }

        mock_result.documents = [mock_doc]

        self.mock_azure_client.begin_analyze_document.return_value.result.return_value = mock_result

        files = {"file": ('imaxe.jpg', b'...', 'image/jpeg')}
        resposta = self.client.post("/extraccion/", files=files)

        self.assertEqual(resposta.status_code, 200)
if __name__ == '__main__':
    unittest.main()