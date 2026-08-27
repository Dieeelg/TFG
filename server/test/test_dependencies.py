import json
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import HTTPException

from app import dependencies


class TestDependenciasAPI(unittest.IsolatedAsyncioTestCase):
    def nova_app(self):
        return SimpleNamespace(state=SimpleNamespace())

    async def test_arranque_con_credenciais_de_contorna(self):
        app = self.nova_app()
        cliente_azure = MagicMock(name="cliente_azure")
        firebase_json = json.dumps({"type": "service_account", "project_id": "proba"})

        with (
            patch.dict(
                dependencies.os.environ,
                {"DOC_INTEL_KEY": "clave-local", "FIREBASE-CREDENTIALS": firebase_json},
                clear=True,
            ),
            patch.object(dependencies, "DefaultAzureCredential") as credential_mock,
            patch.object(dependencies, "AzureKeyCredential") as key_mock,
            patch.object(
                dependencies, "DocumentIntelligenceClient", return_value=cliente_azure
            ) as client_mock,
            patch.object(dependencies.firebase_admin, "_apps", {}),
            patch.object(dependencies.credentials, "Certificate") as certificate_mock,
            patch.object(dependencies.firebase_admin, "initialize_app") as initialize_mock,
        ):
            async with dependencies.lifespan(app):
                self.assertIs(app.state.doc_intel_client, cliente_azure)

        credential_mock.assert_called_once_with()
        key_mock.assert_called_once_with("clave-local")
        client_mock.assert_called_once()
        certificate_mock.assert_called_once_with(json.loads(firebase_json))
        initialize_mock.assert_called_once_with(certificate_mock.return_value)

    async def test_arranque_recupera_ambos_segredos_de_key_vault(self):
        app = self.nova_app()
        kv = MagicMock()
        kv.get_secret.side_effect = [
            SimpleNamespace(value="clave-vault"),
            SimpleNamespace(value=json.dumps({"project_id": "proba"})),
        ]

        with (
            patch.dict(dependencies.os.environ, {}, clear=True),
            patch.object(dependencies, "DefaultAzureCredential") as credential_mock,
            patch.object(dependencies, "SecretClient", return_value=kv) as secret_client_mock,
            patch.object(dependencies, "DocumentIntelligenceClient", return_value=MagicMock()),
            patch.object(dependencies.firebase_admin, "_apps", {}),
            patch.object(dependencies.credentials, "Certificate"),
            patch.object(dependencies.firebase_admin, "initialize_app"),
        ):
            async with dependencies.lifespan(app):
                pass

        self.assertEqual(
            [chamada.args[0] for chamada in kv.get_secret.call_args_list],
            [dependencies.SECRET_NAME, dependencies.FIREBASE_NAME],
        )
        secret_client_mock.assert_called_with(
            vault_url=dependencies.KEY_VAULT_URL,
            credential=credential_mock.return_value,
        )

    async def test_fallo_da_clave_azure_impide_o_arranque(self):
        app = self.nova_app()
        with (
            patch.dict(dependencies.os.environ, {}, clear=True),
            patch.object(dependencies, "DefaultAzureCredential"),
            patch.object(
                dependencies.SecretClient,
                "get_secret",
                side_effect=RuntimeError("Key Vault non dispoñible"),
            ),
        ):
            with self.assertRaisesRegex(RuntimeError, "Key Vault non dispoñible"):
                async with dependencies.lifespan(app):
                    pass

    async def test_fallo_ao_crear_cliente_azure_impide_o_arranque(self):
        app = self.nova_app()
        with (
            patch.dict(dependencies.os.environ, {"DOC_INTEL_KEY": "clave"}, clear=True),
            patch.object(dependencies, "DefaultAzureCredential"),
            patch.object(
                dependencies,
                "DocumentIntelligenceClient",
                side_effect=RuntimeError("configuración Azure inválida"),
            ),
        ):
            with self.assertRaisesRegex(RuntimeError, "configuración Azure inválida"):
                async with dependencies.lifespan(app):
                    pass

    async def test_erros_de_firebase_non_deteñen_a_api(self):
        escenarios = [
            ({}, RuntimeError("sen Firebase en Key Vault")),
            ({"FIREBASE-CREDENTIALS": "json inválido"}, None),
        ]
        for contorna_firebase, erro_vault in escenarios:
            with self.subTest(contorna=contorna_firebase):
                app = self.nova_app()
                contorna = {"DOC_INTEL_KEY": "clave", **contorna_firebase}
                kv = MagicMock()
                if erro_vault:
                    kv.get_secret.side_effect = erro_vault
                with (
                    patch.dict(dependencies.os.environ, contorna, clear=True),
                    patch.object(dependencies, "DefaultAzureCredential"),
                    patch.object(dependencies, "SecretClient", return_value=kv),
                    patch.object(dependencies, "DocumentIntelligenceClient", return_value=MagicMock()),
                    patch.object(dependencies.firebase_admin, "_apps", {}),
                    patch.object(dependencies.firebase_admin, "initialize_app") as initialize_mock,
                ):
                    async with dependencies.lifespan(app):
                        self.assertIsNotNone(app.state.doc_intel_client)
                initialize_mock.assert_not_called()

    async def test_firebase_xa_inicializado_non_se_repite(self):
        app = self.nova_app()
        with (
            patch.dict(
                dependencies.os.environ,
                {"DOC_INTEL_KEY": "clave", "FIREBASE-CREDENTIALS": "{}"},
                clear=True,
            ),
            patch.object(dependencies, "DefaultAzureCredential"),
            patch.object(dependencies, "DocumentIntelligenceClient", return_value=MagicMock()),
            patch.object(dependencies.firebase_admin, "_apps", {"[DEFAULT]": MagicMock()}),
            patch.object(dependencies.firebase_admin, "initialize_app") as initialize_mock,
        ):
            async with dependencies.lifespan(app):
                pass
        initialize_mock.assert_not_called()

    def test_obter_cliente_azure_dispoñible_e_non_dispoñible(self):
        cliente = MagicMock()
        request = SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(doc_intel_client=cliente)))
        self.assertIs(dependencies.obter_cliente_azure(request), cliente)

        request.app.state.doc_intel_client = None
        with self.assertRaises(HTTPException) as contexto:
            dependencies.obter_cliente_azure(request)
        self.assertEqual(contexto.exception.status_code, 500)


if __name__ == "__main__":
    unittest.main()
