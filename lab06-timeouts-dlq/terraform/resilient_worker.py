import json
import time
from datetime import datetime, timezone


def lambda_handler(event, context):
    # Leemos el modo de prueba desde 'event' (por defecto 'ok')
    modo = event.get("modo", "ok")
    evento_id = event.get("evento_id", "sin-id")
    ahora = datetime.now(timezone.utc).isoformat()

    print(
        f"[{ahora}] Inicio | evento_id={evento_id} | modo={modo} | "
        f"request_id={context.aws_request_id if context else 'local'}"
    )

    # 1. Simula una dependencia lenta que supera un timeout corto (p. ej. 6s con timeout=3s)
    if modo == "lento":
        segundos = int(event.get("segundos", 6))
        print(f"Simulando proceso lento durante {segundos}s...")
        time.sleep(segundos)

    # 2. Simula un fallo en el código o en un servicio externo
    if modo == "error":
        raise RuntimeError(f"Fallo simulado procesando evento_id={evento_id}")

    # 3. Camino feliz
    return {
        "statusCode": 200,
        "body": json.dumps({
            "mensaje": "Evento procesado correctamente",
            "evento_id": evento_id,
            "modo": modo
        })
    }