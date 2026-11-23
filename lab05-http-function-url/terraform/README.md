# Lab 5: API HTTP serverless con Lambda Function URL o API Gateway

![](./images/diagrama.png)  

+ **Lab 5: API HTTP serverless con Lambda Function URL o API Gateway**
    - **Utilidad real:** Exponer un webhook, un endpoint de integración o un microservicio ligero accesible por HTTP/HTTPS.
    - **Qué aprenderás:** Parsear cabeceras, parámetros de consulta (queryStringParameters) y cuerpos JSON entrantes (body), devolver respuestas HTTP correctas y entender las diferencias de seguridad y autenticación entre una Function URL y API Gateway.

## INTRODUCCION

+ Cuando expones una función Lambda mediante Lambda Function URL (o API Gateway), AWS actúa como traductor entre Internet y tu función:
    - Un cliente envía una petición HTTP/HTTPS (GET, POST, etc.) con parámetros en la URL (`?nombre=Miguel`), cabeceras (`User-Agent`, `Content-Type`, etc.) y un cuerpo JSON (`{"mensaje":"hola"}`).
    - AWS empaqueta todo eso dentro del diccionario event que recibe `lambda_handler(event, context)`:
        + `event["requestContext"]["http"]["method"]` $\rightarrow$ El método (GET, POST...).
        + `event.get("queryStringParameters")` $\rightarrow$ Diccionario con los parámetros tras el ? de la URL (o None si no hay).
        + `event.get("headers")` $\rightarrow$ Diccionario con las cabeceras HTTP.
        + `event.get("body")` $\rightarrow$ El cuerpo enviado (llega como texto str, así que si es JSON lo convertimos con `json.loads(...)`).
    - Y para que el navegador o curl entiendan la respuesta, tu Lambda devuelve un diccionario con:
        + `statusCode` (200, 400, etc.)
        + `headers` (`{"Content-Type": "application/json"}`)
        + `body` (el JSON convertido a texto con json.dumps(...)).


## FUNCION

+ Funcion python `http_api.py`:
```python
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
```


## TERRAFORM



## TEST Y COMPROBACIONES




## RESUMEN