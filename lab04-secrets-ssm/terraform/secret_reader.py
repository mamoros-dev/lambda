import json
import os
import boto3

# Cliente de SSM creado fuera del handler: se reutiliza entre invocaciones cálidas.
ssm_client = boto3.client("ssm")

# Caché en memoria a nivel de módulo: guarda el valor secreto tras la primera lectura.
_CACHED_SECRET = None


def get_secret_from_ssm(parameter_name: str) -> tuple[str, str]:
    """
    Devuelve (valor_secreto, origen_lectura) donde origen_lectura
    indica si salió de 'cache_memoria' o de 'ssm_parameter_store'.
    """
    global _CACHED_SECRET

    # Si ya tenemos el secreto en memoria en este contenedor cálido, no volvemos a llamar a SSM.
    if _CACHED_SECRET is not None:
        return _CACHED_SECRET, "cache_memoria"

    # Primera lectura (o cold start): consultamos SSM Parameter Store descifrando SecureString.
    response = ssm_client.get_parameter(
        Name=parameter_name,
        WithDecryption=True
    )
    _CACHED_SECRET = response["Parameter"]["Value"]
    return _CACHED_SECRET, "ssm_parameter_store"


def lambda_handler(event, context):
    # El nombre del parámetro se pasa como variable de entorno (no es un secreto, es una ruta).
    parameter_name = os.environ["PARAMETER_NAME"]

    secret_value, source = get_secret_from_ssm(parameter_name)

    # Buena práctica de seguridad: nunca imprimimos el secreto en los logs;
    # solo comprobamos su longitud o una pista mínima para verificar que llegó bien.
    secret_length = len(secret_value)
    masked_preview = f"{secret_value[:2]}***" if secret_length >= 2 else "***"

    print("=== CONSUMO SEGURO DE PARÁMETRO SSM ===")
    print(f"Parámetro     : {parameter_name}")
    print(f"Origen lectura: {source}")
    print(f"Longitud valor: {secret_length} caracteres")
    print(f"Vista enmascar: {masked_preview}")
    print(f"Request ID    : {context.aws_request_id if context else 'local'}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "mensaje": "Parámetro recuperado correctamente",
            "origen_lectura": source,
            "longitud_secreto": secret_length
        })
    }