import json
import os
import logging

import firebase_admin
from fastapi import Request, HTTPException
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.core.credentials import AzureKeyCredential
from contextlib import asynccontextmanager

from firebase_admin import credentials

from app.internal.constants import KEY_VAULT_URL, DOC_INTEL_ENDPOINT, SECRET_NAME, FIREBASE_NAME

@asynccontextmanager
async def lifespan(app):
    """
     Función para xestionar o ciclo de vida da app FastAPI.

     Encárgase de :
     * O arranque da app
     * A utenticación en Azure
     * Creación do cliente de Azure Document Intelligence
     * Deter a API

     Proceso de autenticación:
     1. Intentamos obter a clave de Axure Doc Intell desde a variable de
     contorna chamada DOC_INTEL_KEY.
     2. Se non se atopa dita variable, realizase a autenticación alternativa
     recuperando a clave de Azure Key Vault
     3. Se non se consigue ningunha das dúas a app detense cun erro.

    """
    logging.info("Iniciando conexión cos servizos de Azure...")
    credential = DefaultAzureCredential()

    #Intentamos coller a KEY directamente da variable de contorno
    api_key = os.getenv("DOC_INTEL_KEY")

    if not api_key:
        logging.info("Non se atopou DOC_INTEL_KEY nas variables de contorna, intentando obtelas por Key Vault...")
        try:
            kv_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
            secret = kv_client.get_secret(SECRET_NAME)
            api_key = secret.value
        except Exception as e:
            logging.error(f"ERRO CRÍTICO: Non se atopou ningunha forma de autenticación: {e}")
            raise e

    #Creamos o cliente de Document Intelligence coa clave
    try:
        client = DocumentIntelligenceClient(
            endpoint=DOC_INTEL_ENDPOINT,
            credential=AzureKeyCredential(api_key),
            api_version = "2024-11-30"
        )
        app.state.doc_intel_client = client
        logging.info("Cliente de Azure inicializado correctamente.")
    except Exception as e:
        logging.critical(f"Erro ao crear o cliente de Document Intelligence: {e}")
        raise e

    firebase_json = os.getenv("FIREBASE-CREDENTIALS")

    if not firebase_json:
        logging.info("Non se atopou FIREBASE-CREDENTIALS nas variables de contorna, intentando obtelas do KeyVault...")
        try:
            kv_client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
            firebase_json = kv_client.get_secret(FIREBASE_NAME).value
        except Exception as e:
            logging.critical(f"Erro ao obter as credenciales de Firebase: {e}")

    if firebase_json and not firebase_admin._apps:
        try:
            creds_dict = json.loads(firebase_json)
            cred = credentials.Certificate(creds_dict)
            firebase_admin.initialize_app(cred)
            logging.info("Firebas inicializado correctamente.")
        except Exception as e:
            logging.critical(f"Erro ao inicializar Firebase: {e}")

    yield

    logging.info(f"API Detida correctamente")

def get_azure_client(request: Request) -> DocumentIntelligenceClient:
    client = request.app.state.doc_intel_client
    if not client:
        raise HTTPException(status_code=500, detail="Servizo Azure non dispoñible")
    return client