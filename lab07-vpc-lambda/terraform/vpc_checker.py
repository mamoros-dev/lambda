import json
import os
import socket
import urllib.request
from datetime import datetime, timezone
import boto3


def lambda_handler(event, context):
    ahora = datetime.now(timezone.utc).isoformat()
    region = os.environ.get("AWS_REGION", "eu-west-1")

    # 1. Prueba de salida a internet (debe fallar rápido en subred privada sin NAT)
    socket.setdefaulttimeout(2)
    try:
        urllib.request.urlopen("https://www.google.com", timeout=2)
        estado_internet = "Con salida a internet"
    except Exception as exc:
        estado_internet = f"Bloqueado sin salida a internet ({type(exc).__name__})"

    print(f"[{ahora}] Internet: {estado_internet}")

    # 2. Prueba de acceso privado a S3 mediante Gateway VPC Endpoint (debe funcionar)
    buckets = []
    try:
        s3 = boto3.client("s3", region_name=region)
        resp = s3.list_buckets()
        buckets = [b["Name"] for b in resp.get("Buckets", [])]
        estado_s3 = f"OK via VPC Endpoint ({len(buckets)} buckets visibles)"
    except Exception as exc:
        estado_s3 = f"Error S3: {exc}"

    print(f"[{ahora}] S3: {estado_s3}")

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "timestamp_utc": ahora,
            "estado_internet": estado_internet,
            "estado_s3": estado_s3,
            "buckets": buckets
        })
    }