import json
from datetime import datetime, timezone

def lambda_handler(event, context):
    # Obtenemos la hora exacta de ejecución en formato ISO 8601 (ej. "2026-11-20T00:15:00+00:00")
    ejecutado_en = datetime.now(timezone.utc).isoformat()

    # EventBridge suele enviar información del evento dentro de "event" (o puede ir vacío si se prueba a mano)
    fuente = event.get("source", "invocacion-manual-o-scheduler")

    print("=== TAREA PROGRAMADA EJECUTADA ===")
    print(f"Timestamp UTC : {ejecutado_en}")
    print(f"Origen        : {fuente}")
    print(f"Request ID    : {context.aws_request_id if context else 'local'}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "mensaje": "Tarea programada ejecutada correctamente",
            "timestamp_utc": ejecutado_en
        })
    }