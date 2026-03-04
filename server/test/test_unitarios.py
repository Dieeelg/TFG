import unittest
from datetime import datetime
from server.app.internal.logic import *

class TestSintromUnit(unittest.TestCase):
    """
    Tests unitarios para as funcións de procesamento de texto,datas, calculo da confianza media ...
    """

    def test_parse_dose_cell_tomar(self):
        """
        Comprobamos que a pesar de que a dose cambie de sitio se detecta todo correctamente
        """
        casos = ["27 MAR 1/2", "27 1/2 MAR"]
        for texto in casos:
            with self.subTest(text=texto):
                resultado = parse_dose_cell(texto, 2026, 3)
                self.assertEqual(resultado["dose"], "1/2")
                self.assertEqual(resultado["accion"], "TOMAR")
                self.assertEqual(resultado["data"], "2026-03-27")
                self.assertEqual(resultado["control"], False)

    def test_parse_dose_cell_non_tomar(self):
        """
        Comprobamos que se detecta todo correctamente a pesar de que:
        * Non se detecte ou cambie de sitio a dose
        * Se detecte ou non NO TOMAR
        """
        casos = ["15 0 ABR NO TOMAR", "15 ABR NO TOMAR",
                 "15 0 ABR", "15 ABR 0", "15 ABR 0 NO TOMAR",
                 "15 ABR NO TOMAR 0", "15 ABR NO 0 TOMAR"]
        for texto in casos:
            with self.subTest(text=texto):
                resultado = parse_dose_cell(texto, 2026, 4)
                self.assertEqual(resultado["dose"], "0")
                self.assertEqual(resultado["accion"], "NON TOMAR")
                self.assertEqual(resultado["data"], "2026-04-15")
                self.assertEqual(resultado["control"], False)

    def test_parse_dose_cell_control(self):
        """
        Comprobamos que se detecta correctamente o día do control no calendario
        """
        casos = ["20 MAY CONTROL", "20 CONTROL MAY",
                 "CONTROL 20 MAY", "CONTROL MAY 20",
                 "MAY CONTROL 20", "MAY 20 CONTROL"]
        for texto in casos:
            with self.subTest(text=texto):
                resultado = parse_dose_cell(texto, 2026, 5)
                self.assertEqual(resultado["dose"], None)
                self.assertEqual(resultado["accion"], "CONTROL")
                self.assertEqual(resultado["data"], "2026-05-20")
                self.assertEqual(resultado["control"], True)

    def test_parse_dose_cell_cambio_ano(self):
        """
        Comprobamos que no caso de que no calendario teñamos cambio de ano, este se realice de forma correcta
        """
        resultado = parse_dose_cell("08 ENE 1", 2025, 12)
        self.assertEqual(resultado["data"], "2026-01-08")

    def test_parse_dose_cell_errores(self):
        """Comproba que parse_dose_cell devolve None ante lixo ou datas mal formadas"""

        self.assertIsNone(parse_dose_cell("", 2026, 12))
        self.assertIsNone(parse_dose_cell("HOLA MUNDO", 2026, 1))
        self.assertIsNone(parse_dose_cell("20 LJLHSHS 1/2", 2026, 1))
        self.assertIsNone(parse_dose_cell("ENE 1/2", 2026, 1))
        self.assertIsNone(parse_dose_cell("30 FEB 1", 2026, 2))
        self.assertIsNone(parse_dose_cell(None, 2026, 1))
        self.assertIsNone(parse_dose_cell("ABR", 2026, 2))

    def test_extraer_data(self):
        """
        Comrpobamos que a función axuliar extraer data limpa a pesar de ter texto lixo ao redor e
        que funciona correctaemnte con ambos formatos de data (DD/MM/YYYY ou YYYY-MM-DD).
        """
        self.assertEqual(extraer_data("Próxima visita: Lunes, 20/01/2025 ...."), "20/01/2025")
        self.assertEqual(extraer_data("Fecha.........:2018-03-27 10:38:02"), "2018-03-27")

    def test_extraer_data_erros(self):
        """
        Casos de fallo ou mala detección da data na función extraer_data
        """
        self.assertIsNone(extraer_data(None))
        self.assertIsNone(extraer_data(""))
        self.assertIsNone(extraer_data("Texto sen ningunha data"))

    def test_patsear_data(self):
        """
        Comprobamos que funciona correctamente a funciona parsear_data con ambos formatos de data
        (DD/MM/YYYY ou YYYY-MM-DD).
        """
        casos = [
            # (Entrada, Resultado Esperado)
            ("2024-01-31", datetime(2024, 1, 31)),
            ("31/01/2024", datetime(2024, 1, 31)),
            ("2023-12-25", datetime(2023, 12, 25)),
            ("01/05/2023", datetime(2023, 5, 1)),
        ]
        for entrada, referencia in casos:
            with self.subTest(text=entrada):
                resultado = parsear_data(entrada)
                self.assertEqual(resultado, referencia)

    def test_parsear_data_entradas_valeiras(self):
        """
        Comprobación de que a función parsear_data devolve None se non reecibe ningún dato.
        """
        casos = [None, "", "   "]
        for texto in casos:
            with self.subTest(text=texto):
                resultado = parsear_data(texto)
                self.assertIsNone(resultado)

    def test_parsear_data_entrada_invalida(self):
        """
        Comprobación de que devolve None cando recibe texto que non é unha data ou datas mal formadas.
        """
        casos = [
            "hola mundo",
            "32/01/2024",
            "2024/01/31",
            "31-01-2024",
            "2024-02-30",
            "123456"
        ]
        for entrada in casos:
            with self.subTest(entrada=entrada):
                self.assertIsNone(parsear_data(entrada))

    def test_extraer_dose_semanal_exito(self):
        """
        Comprobación de que identifica correctamente o patrón nº + mg e elimina o resto
        """
        casos = [
            ("13,5 mg (1/2 día - DOM alternos)", "13,5 mg"),
            ("4 mg", "4 mg"),
            ("2.5 mg", "2.5 mg"),
            ("2.5mg", "2.5mg"),
            ("   10mg   ", "10mg")
        ]
        for entrada, referencia in casos:
            with self.subTest(text=entrada):
                self.assertEqual(extraer_dose_semanal(entrada), referencia)

    def test_extraer_dose_semanal_fallo_paton(self):
        """
        Comprobación de que devolve o texto de entrada tal cual se non atopa o patron de nº+mg
        """
        self.assertEqual(extraer_dose_semanal("13,5 (1/2 día - DOM alternos)"), "13,5 (1/2 día - DOM alternos)")

    def test_extraer_dose_semanal_entrada_baleira(self):
        """Comprobación de que devolve None se recibe unha entrada baleira"""
        self.assertIsNone(extraer_dose_semanal(None))
        self.assertIsNone(extraer_dose_semanal(""))

if __name__ == '__main__':
    unittest.main()