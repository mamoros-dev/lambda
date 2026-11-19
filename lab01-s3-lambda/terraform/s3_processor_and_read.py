import json
import urllib.parse
import boto3

s3_client = boto3.client("s3")


def lambda_handler(event, context):
    print("--- EVENTO RECIBIDO DESDE S3 ---")

    for record in event.get("Records", []):
        bucket_name = record["s3"]["bucket"]["name"]
        object_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        event_name = record.get("eventName", "desconocido")

        print(f"Evento: {event_name} | Bucket: {bucket_name} | Archivo: {object_key}")

        # 1. Pedimos el objeto completo a S3
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)

        # 2. response["Body"] es un flujo de bytes (stream).
        #    .read() lee todos los bytes y .decode("utf-8") los convierte a texto legible.
        contenido = response["Body"].read().decode("utf-8", errors="replace")

        print(f"Contenido del archivo:\n{contenido}")

    return {
        "statusCode": 200,
        "body": json.dumps({"mensaje": "Archivo leído correctamente"})
    }