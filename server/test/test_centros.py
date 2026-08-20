import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app
from app.routers import centros


class TestCentrosSanitarios(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        centros._cargar_centros.cache_clear()

    def tearDown(self):
        centros._cargar_centros.cache_clear()

    def test_normalizacion_e_extraccion_da_descripcion(self):
        self.assertEqual(
            centros._normalizar("  C.S. A Coruña - Centro de Saúde "),
            "CENTRO SAUDE A CORUNA CENTRO SAUDE",
        )
        campos = centros._campos_descripcion(
            "<table><tr><td><b>NOMBRE</b></td><td>C.S. VIVEIRO &amp; Norte</td></tr>"
            "<tr><td>TELEFONO</td><td><span>982 000 000</span></td></tr></table>"
        )
        self.assertEqual(campos["NOMBRE"], "C.S. VIVEIRO & Norte")
        self.assertEqual(campos["TELEFONO"], "982 000 000")

    def test_carga_kml_e_descarta_rexistros_incompletos(self):
        kml = """<?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2"><Document>
          <Placemark><name>Nome KML</name><description><![CDATA[
            <table><tr><td>NOMBRE</td><td>C.S. VIVEIRO</td></tr>
            <tr><td>TELEFONO</td><td>982111111</td></tr>
            <tr><td>DIRECCION</td><td>Rúa Principal</td></tr>
            <tr><td>CONCELLO</td><td>Viveiro</td></tr></table>
          ]]></description></Placemark>
          <Placemark><name>Sen teléfono</name><description /></Placemark>
          <Placemark><description><![CDATA[
            <table><tr><td>TELEFONO</td><td>999</td></tr></table>
          ]]></description></Placemark>
        </Document></kml>"""
        with tempfile.TemporaryDirectory() as temporal:
            ruta = Path(temporal) / "centros.kml"
            ruta.write_text(kml, encoding="utf-8")
            with patch.object(centros, "KML_PATH", ruta):
                resultado = centros._cargar_centros()

        self.assertEqual(len(resultado), 1)
        self.assertEqual(resultado[0]["nome"], "C.S. VIVEIRO")
        self.assertEqual(resultado[0]["nome_normalizado"], "CENTRO SAUDE VIVEIRO")
        self.assertEqual(resultado[0]["enderezo"], "Rúa Principal")

    def test_carga_sen_catalogo(self):
        with patch.object(centros, "KML_PATH", Path("catalogo-que-non-existe.kml")):
            with self.assertRaisesRegex(RuntimeError, "Non se atopou"):
                centros._cargar_centros()

    def test_busca_exacta_e_aproximada(self):
        catalogo = [
            {
                "nome": "C.S. VIVEIRO",
                "nome_normalizado": "CENTRO SAUDE VIVEIRO",
                "telefono": "982111111",
                "enderezo": "Rúa Principal",
                "concello": "Viveiro",
            }
        ]
        with patch.object(centros, "_cargar_centros", return_value=catalogo):
            exacta = self.client.get("/centros/buscar", params={"nome": "CS Viveiro"})
            aproximada = self.client.get("/centros/buscar", params={"nome": "Viveiro"})

        self.assertEqual(exacta.status_code, 200)
        self.assertEqual(aproximada.status_code, 200)
        self.assertEqual(exacta.json()["telefono"], "982111111")
        self.assertIn("Xunta de Galicia", exacta.json()["fonte"])

    def test_busca_sen_resultados_e_consulta_demasiado_curta(self):
        with patch.object(centros, "_cargar_centros", return_value=[]):
            baleira = self.client.get("/centros/buscar", params={"nome": "Viveiro"})
        with patch.object(
            centros,
            "_cargar_centros",
            return_value=[{
                "nome": "Hospital de Lugo",
                "nome_normalizado": "HOSPITAL DE LUGO",
                "telefono": "982000000",
                "enderezo": None,
                "concello": "Lugo",
            }],
        ):
            afastada = self.client.get("/centros/buscar", params={"nome": "Xunqueira"})
        curta = self.client.get("/centros/buscar", params={"nome": "A"})

        self.assertEqual(baleira.status_code, 404)
        self.assertEqual(afastada.status_code, 404)
        self.assertEqual(curta.status_code, 422)

    def test_erro_de_catalogo_convírtese_en_503(self):
        for erro in (OSError("sen acceso"), RuntimeError("sen catálogo")):
            with self.subTest(erro=type(erro).__name__):
                with patch.object(centros, "_cargar_centros", side_effect=erro):
                    resposta = self.client.get("/centros/buscar", params={"nome": "Viveiro"})
                self.assertEqual(resposta.status_code, 503)


if __name__ == "__main__":
    unittest.main()
