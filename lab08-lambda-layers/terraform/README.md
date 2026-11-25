# Lab 8: Capas (Lambda Layers) y empaquetado de dependencias externas

![](./images/diagrama.png)  

+ **Lab 8: Capas (Lambda Layers) y empaquetado de dependencias externas**
    - **Utilidad real:** Reutilizar librerías de terceros (como requests o clientes específicos) o utilidades compartidas entre varias funciones sin duplicar código ni inflar cada despliegue.
    - **Qué aprenderás:** Crear y versionar un aws_lambda_layer_version, estructurar carpetas (python/ para Python) y decidir cuándo usar una Layer, empaquetar dependencias en el .zip o pasar a un contenedor Docker en ECR.

## INTRODUCCION

+ El Lab 8 es serverless. Hasta ahora hemos usado solo la librería estándar de Python y boto3 (que ya viene incluido en el runtime de Lambda). En proyectos reales, casi siempre necesitas librerías externas (como requests, pydantic, etc.) o funciones auxiliares compartidas entre varias Lambdas.

+ Qué es una Lambda Layer y cómo funciona en Python:
    - **Una Lambda Layer es un paquete .zip** (hasta 50 MB comprimido / ~250 MB descomprimido sumando función y capas) que AWS monta automáticamente en el directorio /opt del entorno de ejecución cuando arranca la función.
    - **Estructura obligatoria para Python 3.11:** Python busca librerías adicionales en /opt/python. Por eso, el .zip de la capa debe tener dentro una carpeta python/ (por ejemplo python/requests/... o python/utilidades.py). Si metes los archivos sueltos en la raíz del .zip sin la carpeta python/, Python no los encontrará al hacer import.
    - **Versionado:** Cada vez que cambia el contenido de la capa, Terraform crea una nueva versión (aws_lambda_layer_version, versión 1, 2, 3...) y actualiza la función Lambda para apuntar al nuevo ARN de versión.


+ **¿Cuándo elegir Layer, .zip de función o contenedor Docker en ECR?:**
    - **Dependencia en el propio .zip de la función:** ideal cuando solo una función usa la librería y el paquete es pequeño; el despliegue es autocontenido.
    - **Lambda Layer (aws_lambda_layer_version):** útil cuando varias funciones comparten las mismas librerías o utilidades y quieres separar el código de negocio (que cambia a menudo) de las dependencias (que cambian poco), manteniendo el .zip de cada función ligero.
    - **Contenedor Docker en Amazon ECR:** mejor opción cuando las dependencias son pesadas (superan los límites de .zip + layers), incluyen binarios/librerías del sistema operativo o ya estandarizas tus despliegues como imágenes de contenedor.

+ Qué vamos a montar en este Lab 8:
    - Una carpeta local layer_build/python/ con un módulo de utilidad propio (por ejemplo helpers.py) y/o una librería externa instalada en layer_build/python/.
    - Un recurso aws_lambda_layer_version en Terraform que empaqueta esa carpeta en .zip y publica la capa en eu-west-1 para python3.11.
    - Una función Lambda (lab8-layers-demo) enlazada a esa capa mediante layers = [aws_lambda_layer_version.shared_layer.arn], que importa el módulo desde la capa y responde con un JSON.

+ Elegir entre empaquetar en el .zip de la función, usar una Lambda Layer o desplegar una imagen de contenedor en ECR depende del tamaño de las dependencias, de cuántas funciones las comparten y de qué tan complejo sea el entorno que necesita tu código:
    - **Empaquetar dependencias directamente en el .zip de la función:** Es el enfoque más directo: metes tu código (handler.py) y tus librerías (pip install -t ... o similar) dentro del mismo paquete de despliegue de esa función.
        + Cuándo conviene:
            - Tienes una sola función (o pocas) que necesita una o dos librerías ligeras.
            - Quieres un despliegue autocontenido: al mirar esa Lambda, todo lo que necesita está en su propio paquete sin depender de versiones externas de una capa.
            - El .zip resultante es pequeño y rápido de subir/actualizar.
        + Cuándo no conviene:
            - Tienes 8 o 10 Lambdas que repiten las mismas dependencias pesadas y subes megas innecesarios cada vez que cambias dos líneas de tu código de negocio.

    - **Usar una Lambda Layer (aws_lambda_layer_version):** Una Layer es un paquete .zip separado que AWS monta en /opt (y en Python /opt/python entra en la ruta de importación) y que puedes asociar a una o varias funciones.
        + Cuándo conviene:
            - Varias funciones comparten dependencias o utilidades (por ejemplo, clientes internos, formateadores de logs, validaciones comunes o una librería de terceros usada en varios microservicios).
            - Quieres separar el ciclo de vida: el código de negocio cambia a diario, pero la librería o utilidad compartida cambia poco y se versiona de forma independiente.
            - Quieres mantener el .zip de cada función pequeño para que la revisión de código y el despliegue de la función sean ligeros.
        + Puntos a vigilar en la práctica:
            - Cada nueva versión de la capa (v1, v2, v3...) tiene su propio ARN; si actualizas la capa y quieres que las Lambdas usen la nueva versión, debes actualizar su referencia en Terraform (layers = [...]).
            - Sigue habiendo límites de tamaño (50 MB comprimidos / ~250 MB descomprimidos en total sumando código de función y capas).

    - **Usar un contenedor Docker en Amazon ECR:** En lugar de subir un .zip con un runtime gestionado por AWS, empaquetas tu código y dependencias dentro de una imagen de contenedor (basada en las imágenes base de AWS Lambda o compatible con su runtime API) y la subes a Amazon ECR.
        + Cuándo conviene:
            - Tus dependencias superan cómodamente los límites de .zip + Layers (por ejemplo, librerías pesadas de ciencia de datos, machine learning, procesamiento pesado de imágenes/vídeo o frameworks grandes).
            - Necesitas binarios o librerías del sistema operativo difíciles de empaquetar a mano en un .zip (por ejemplo ffmpeg, herramientas nativas de Linux o compilaciones específicas).
            - Tu equipo ya estandariza todo el CI/CD y las pruebas locales con Docker, o ya tienes pipelines construyendo imágenes en ECR.
        + Puntos a vigilar en la práctica:
            - Construir y subir imágenes Docker suele ser algo más lento en CI/CD que empaquetar un .zip ligero, y los cold starts pueden ser mayores si la imagen es pesada.

## FUNCION

+ **Módulo de utilidad compartido (layer_build/python/helpers.py):** Este módulo simula una utilidad común (por ejemplo, normalizar textos o formatear respuestas/metadatos de evento) que distintas Lambdas podrían reutilizar sin duplicar lógica:
```bash
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
        "etiqueta_normalizada": normalizar_etiqueta(etiqueta),
        "generado_utc": datetime.now(timezone.utc).isoformat(),
        "detalle": detalle,
    }
```

+ **Función Lambda (layer_handler.py):** La función importa directamente construir_respuesta desde helpers (resuelto automáticamente gracias a que AWS monta la capa en /opt/python):
```bash
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
```

## TERRAFORM

## TEST Y COMPROBACIONES

## RESUMEN