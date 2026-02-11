# Endpoints de Azure ACORDARSE DE CAMBIAR A COLLELAS DO ENTORNO MELLOR
KEY_VAULT_URL = "https://almacen-tfg-sintrom.vault.azure.net/"
DOC_INTEL_ENDPOINT = "https://tfg-sintrom.cognitiveservices.azure.com/"

#Nome do segredo a recuperar
SECRET_NAME = "key-document-intelligence"

#Nome do modelo adestrado que imos a empregar
MODEL_ID = "M2"

#Columnas da táboa de dose
DOSE_COLS = ["LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SÁBADO", "DOMINGO"]

#Dicionario para mapear os meses de texto a número.
MESES_MAP ={
    "ENE": 1, "FEB": 2, "MAR": 3, "ABR": 4, "MAY": 5,
    "JUN": 6, "JUL": 7, "AGO": 8, "SEP": 9, "OCT": 10,
    "NOV": 11, "DIC": 12, "DEC": 12
}

# Definimos límites de seguridad para validación de INR
INR_MIN_LOGICO = 0.5
INR_MAX_LOGICO = 10.0