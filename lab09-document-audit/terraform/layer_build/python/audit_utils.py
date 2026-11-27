import hashlib
import re
from datetime import datetime, timezone


def limpiar_nombre_archivo(object_key: str) -> str:
    """Normaliza la ruta/nombre del objeto de S3 para guardarlo de forma limpia."""
    if not object_key:
        return "archivo-desconocido"
    # Sustituye caracteres especiales por guiones manteniendo letras, números, puntos y barras
    limpio = re.sub(r"[^a-zA-Z0-9._/-]+", "-", object_key.strip())
    return limpio[:256]


def generar_id_documento(bucket: str, object_key: str, etag: str) -> str:
    """Genera un identificador SHA-256 determinista a partir de bucket, clave y ETag."""
    base = f"{bucket}|{object_key}|{etag or 'sin-etag'}"
    return hashlib.sha256(base.encode("utf-8")).hexdigest()


def preparar_registro_auditoria(
    bucket: str,
    object_key: str,
    size_bytes: int,
    etag: str,
    event_time: str | None = None,
) -> dict:
    """Construye el diccionario de metadatos listo para persistir en DynamoDB."""
    procesado_utc = datetime.now(timezone.utc).isoformat()
    return {
        "document_id": generar_id_documento(bucket, object_key, etag),
        "bucket": bucket,
        "object_key": object_key,
        "nombre_limpio": limpiar_nombre_archivo(object_key),
        "size_bytes": int(size_bytes),
        "etag": (etag or "").strip('"'),
        "event_time": event_time or procesado_utc,
        "procesado_utc": procesado_utc,
        "estado": "CATALOGADO",
    }