import json
import urllib.error
import urllib.request
from datetime import datetime, timezone


def lambda_handler(event, context):
    # Hora exacta de ejecución en UTC (estándar en cloud para evitar líos horarios)
    ejecutado_en = datetime.now(timezone.utc).isoformat()

    # Identifica quién llamó a la función (por ejemplo "aws.scheduler.lab3" o "prueba-manual")
    fuente = event.get("source", "invocacion-manual")

    # URL a comprobar: si no viene en 'event', usamos un endpoint de prueba fiable
    url = event.get("url", "https://httpbin.org/get")

    # Hacemos una petición HTTP con timeout de 5 segundos para que la Lambda no se quede colgada
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Lab3-HealthCheck/1.0"})
        with urllib.request.urlopen(req, timeout=5) as response:
            status_http = response.status
            estado_servicio = "UP" if 200 <= status_http < 300 else "DEGRADED"
    except urllib.error.HTTPError as exc:
        # El servidor respondió con un error HTTP (4xx o 5xx)
        status_http = exc.code
        estado_servicio = "DOWN_HTTP_ERROR"
    except Exception as exc:
        # Error de red, DNS, timeout, etc.
        status_http = None
        estado_servicio = f"DOWN_ERROR: {exc}"

    # Imprimimos el resultado para que quede registrado en CloudWatch Logs
    print("=== CHEQUEO DE SALUD (HEALTH CHECK) ===")
    print(f"Timestamp UTC : {ejecutado_en}")
    print(f"Origen        : {fuente}")
    print(f"URL revisada  : {url}")
    print(f"HTTP Status   : {status_http}")
    print(f"Estado        : {estado_servicio}")
    print(f"Request ID    : {context.aws_request_id if context else 'local'}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "timestamp_utc": ejecutado_en,
            "url": url,
            "http_status": status_http,
            "estado": estado_servicio
        })
    }