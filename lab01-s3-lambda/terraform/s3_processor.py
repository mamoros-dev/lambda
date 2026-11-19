import json          # Sirve para convertir diccionarios de Python a texto JSON (y viceversa)
import urllib.parse  # Ayuda a decodificar nombres de archivos (por ejemplo, si hay espacios o tildes en la URL)
import boto3         # SDK oficial de AWS para Python: permite hablar con S3, DynamoDB, etc.

# Creamos el cliente de S3 fuera de lambda_handler para reutilizar la conexión
# entre invocaciones "cálidas" (warm starts) y ahorrar tiempo de ejecución.
s3_client = boto3.client("s3")


def lambda_handler(event, context):
    print("--- EVENTO RECIBIDO DESDE S3 ---")

    # S3 envía los eventos dentro de una lista llamada "Records".
    # Usamos event.get("Records", []) para que, si no hay "Records", devuelva [] y no falle.
    for record in event.get("Records", []):
        # Navegamos por los diccionarios anidados que manda S3 en el evento
        bucket_name = record["s3"]["bucket"]["name"]

        # S3 codifica caracteres especiales en object["key"] (ej. "mi+archivo.txt" o "carpeta%201/foto.png").
        # unquote_plus convierte eso de nuevo a un texto legible normal.
        object_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        # Obtenemos qué ocurrió (por ejemplo, "ObjectCreated:Put")
        event_name = record.get("eventName", "desconocido")

        print(f"Evento: {event_name} | Bucket: {bucket_name} | Archivo: {object_key}")

        # Consultamos metadatos básicos del objeto subido (mínimo privilegio: HeadObject / GetObject)
        # head_object pide a S3 solo los metadatos del archivo (tamaño, tipo, fecha)
        # sin descargar todo el contenido del archivo.
        head = s3_client.head_object(Bucket=bucket_name, Key=object_key)
        print(
            f"Tamaño: {head['ContentLength']} bytes | "
            f"Content-Type: {head.get('ContentType', 'N/A')} | "
            f"Última modificación: {head['LastModified']}"
        )

    # Respuesta estándar de la función al terminar
    return {
        "statusCode": 200,
        "body": json.dumps({"mensaje": "Procesamiento de evento S3 completado"})
    }
