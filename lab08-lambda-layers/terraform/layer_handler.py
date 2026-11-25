import json
from helpers import construir_respuesta


def lambda_handler(event, context):
    etiqueta_entrada = event.get("etiqueta", "Lab 8 Layers Demo")
    payload_extra = event.get("datos", {})

    resultado = construir_respuesta(
        origen="lab8-shared-utils-layer",
        etiqueta=etiqueta_entrada,
        detalle={
            "request_id": context.aws_request_id if context else "local",
            "datos_recibidos": payload_extra,
        },
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(resultado),
    }