import json
import boto3
import os
import socket
import urllib.request
from datetime import datetime, timezone

def lambda_handler(event, context):
    ahora = datetime.now(timezone.utc).isoformat()
    region = os.environ.get("AWS_REGION", "unknown")
    
    # 1. Información de red local de la Lambda (IP, hostname)
    ip_address = socket.gethostbyname(socket.gethostname())
    print(f"[{ahora}] Lambda IP interna: {ip_address}")
    
    # 2. Intentar acceder a un servicio público (sin NAT Gateway esto fallará)
    # Probamos conectar a Google para demostrar que no hay salida a internet
    try:
        print("Probando conexión a internet (google.com)...")
        urllib.request.urlopen("https://www.google.com", timeout=5)
        internet_access = "Conexión a internet detectada"
        print("¡ALERTA! La Lambda tiene salida a internet.")
    except Exception as e:
        internet_access = f"Sin salida a internet directa: {str(e)}"
        print(f"Correcto: Sin salida a internet directa. ({str(e)})")

    # 3. Intentar acceder a AWS S3 (esto SÍ funcionará si está el Gateway Endpoint)
    s3_access = "Desconocido"
    s3_buckets = []
    try:
        print(f"Intentando listar buckets de S3 en región {region} vía VPC Endpoint...")
        # Boto3 usará automáticamente el Gateway Endpoint si la VPC está bien configurada
        s3_client = boto3.client("s3", region_name=region)
        response = s3_client.list_buckets()
        s3_buckets = [bucket["Name"] for bucket in response["Buckets"]]
        s3_access = f"Éxito: {len(s3_buckets)} buckets encontrados"
        print(f"Acceso a S3 vía VPC Endpoint correcto. Buckets: {s3_buckets}")
    except Exception as e:
        s3_access = f"Error de acceso a S3: {str(e)}"
        print(f"Error crítico: No se pudo acceder a S3. {str(e)}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "mensaje": "Verificación de Lambda dentro de VPC",
            "timestamp_utc": ahоra,
            "ip_lambda": ip_address,
            "estado_internet": internet_access,
            "estado_s3": s3_access,
            "lista_buckets_s3": s3_buckets
        })
    }