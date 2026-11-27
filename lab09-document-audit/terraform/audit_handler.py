import json
import os
import boto3
from audit_utils import preparar_registro_auditoria


def lambda_handler(event, context):
    table_name = os.environ["AUDIT_TABLE_NAME"]
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(table_name)

    records = event.get("Records", [])
    print(f"Recibidos {len(records)} registro(s) en tabla {table_name}")

    procesados = []

    for record in records:
        s3_info = record.get("s3", {})
        bucket_name = s3_info.get("bucket", {}).get("name", "")
        obj_info = s3_info.get("object", {})
        object_key = obj_info.get("key", "")
        size_bytes = obj_info.get("size", 0)
        etag = obj_info.get("eTag", "")
        event_time = record.get("eventTime")

        # Gancho controlado para probar reintentos y envío a SQS DLQ en el Lab 09
        if "forzar-error" in object_key.lower():
            raise RuntimeError(f"Fallo simulado de auditoria para el archivo: {object_key}")

        item = preparar_registro_auditoria(
            bucket=bucket_name,
            object_key=object_key,
            size_bytes=size_bytes,
            etag=etag,
            event_time=event_time,
        )

        table.put_item(Item=item)
        print(f"Registrado en DynamoDB: document_id={item['document_id']} key={object_key}")
        procesados.append(item["document_id"])

    return {
        "statusCode": 200,
        "body": json.dumps({
            "procesados": len(procesados),
            "document_ids": procesados,
        }),
    }