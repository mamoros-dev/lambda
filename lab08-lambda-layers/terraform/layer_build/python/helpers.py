import re
from datetime import datetime, timezone


def normalizar_etiqueta(texto: str) -> str:
    """Limpia espacios extra y devuelve una etiqueta en minúsculas separada por guiones."""
    if not texto:
        return "sin-etiqueta"
    limpio = re.sub(r"[^a-zA-Z0-9]+", "-", texto.strip().lower()).strip("-")
    return limpio or "sin-etiqueta"


def construir_respuesta(origen: str, etiqueta: str, detalle: dict) -> dict:
    """Construye un diccionario uniforme con marca de tiempo UTC para reutilizar en Lambdas."""
    return {
        "origen_capa": origen,
        "version_utilidad": "v2",
        "etiqueta_normalizada": normalizar_etiqueta(etiqueta),
        "generado_utc": datetime.now(timezone.utc).isoformat(),
        "detalle": detalle,
    }