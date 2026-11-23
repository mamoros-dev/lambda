import json
from datetime import datetime, timezone


def lambda_handler(event, context):
    # 1. Extraemos el método HTTP (GET, POST, etc.) desde requestContext
    http_info = event.get("requestContext", {}).get("http", {})
    metodo = http_info.get("method", "UNKNOWN")
    ruta = http_info.get("path", "/")

    # 2. Extraemos los parámetros de consulta (?nombre=Miguel&curso=aws)
    # Si no vienen parámetros, get("queryStringParameters") puede devolver None, por eso usamos "or {}"
    query_params = event.get("queryStringParameters") or {}

    # 3. Extraemos cabeceras relevantes (en Function URL vienen en minúsculas)
    headers = event.get("headers") or {}
    user_agent = headers.get("user-agent", "desconocido")

    # 4. Si llega un cuerpo (body) en un POST, intentamos parsearlo como JSON
    raw_body = event.get("body")
    parsed_body = None
    if raw_body:
        try:
            parsed_body = json.loads(raw_body)
        except json.JSONDecodeError:
            # Si el cliente envió un JSON mal formado, devolvemos HTTP 400 (Bad Request)
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({
                    "error": "El cuerpo de la petición no es un JSON válido"
                })
            }

    # Dejamos registro en CloudWatch Logs
    print(f"HTTP {metodo} {ruta} | query={query_params} | body={parsed_body}")

    # 5. Devolvemos respuesta HTTP 200 con formato JSON estándar
    respuesta = {
        "mensaje": "API Serverless Lab 5 operativa",
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "peticion_recibida": {
            "metodo": metodo,
            "ruta": ruta,
            "query_params": query_params,
            "user_agent": user_agent,
            "body_json": parsed_body
        }
    }

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(respuesta)
    }