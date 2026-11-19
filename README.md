# LAMBDA

## INTRODUCCION

+ Una **AWS Lambda** es una función de código que se ejecuta bajo demanda sin que tú tengas que aprovisionar, configurar ni mantener ningún servidor (por eso se llama Serverless o computación sin servidores).

+ **El modelo Lambda:** Con Lambda, el código está "dormido" y no consume recursos de infraestructura. Cuando ocurre un evento (una petición HTTP, un mensaje en una cola, un comando manual de la CLI), AWS despierta el código en milisegundos en un contenedor efímero (Firecracker), procesa la petición y vuelve a apagarse inmediatamente. Pagas exclusivamente por los milisegundos exactos que tarda en ejecutarse.

+ Para qué sirve realmente esta función Lambda y cuál es su utilidad práctica:
    - **Procesamiento de eventos en tiempo real:** Cada vez que un usuario sube una foto a un bucket de S3, se dispara una Lambda automáticamente para redimensionarla o generar miniatura.

    - **APIs Web Serverless:** Funciona como el "cerebro" o backend detrás de un endpoint HTTP (usando API Gateway) para registrar usuarios, procesar pagos o consultar bases de datos, pagando cero euros cuando nadie la usa.

    - **Tareas de mantenimiento automatizadas (Cron Jobs):** Una Lambda que se ejecuta cada noche a las 2:00 AM para limpiar bases de datos temporales, generar reportes de costes de AWS o hacer backups.

## Roadmap de 8 Laboratorios Prácticos con AWS Lambda y Terraform

+ **Lab 1: Procesador de archivos en S3 (Arquitectura orientada a eventos)**
    - **Utilidad real:** Automatizar el procesamiento de ficheros subidos por usuarios o sistemas externos (validación de formatos, parseo de CSV/JSON, generación de resúmenes o auditoría).
    - **Qué aprenderás:** Cómo configurar una notificación de evento en un bucket de S3 para disparar una Lambda, leer el event real que envía S3 (nombre del bucket y clave del objeto) y dar permisos granulares (s3:GetObject) solo sobre ese bucket.

+ **Lab 2: Escritura y consulta en DynamoDB (Persistencia serverless con boto3)**
    - **Utilidad real:** Guardar registros de auditoría, estados de procesos o datos de microservicios sin gestionar bases de datos relacionales.
    - **Qué aprenderás:** Usar el SDK boto3 de Python dentro de Lambda para hacer put_item o get_item en una tabla DynamoDB, y aplicar mínimo privilegio en IAM restringiendo el recurso al ARN exacto de la tabla.

+ **Lab 3: Tarea programada con EventBridge Scheduler (Reemplazo moderno de cron jobs)**
    - **Utilidad real:** Limpieza periódica de recursos, comprobaciones de salud, envíos de reportes diarios o apagado/encendido de entornos de laboratorio fuera de horario.
    - **Qué aprenderás:** Disparar una Lambda según una expresión cron o de tasa (rate), añadir permisos de invocación (aws_lambda_permission) para que el servicio disparador pueda llamar a la función, y diseñar funciones idempotentes.

+ **Lab 4: Consumo seguro de secretos y parámetros (SSM Parameter Store / Secrets Manager)**
    - **Utilidad real:** Conectar una Lambda a APIs externas, bases de datos o servicios de terceros sin dejar contraseñas o tokens escritos en el código ni en variables de entorno planas.
    - **Qué aprenderás:** Recuperar parámetros o secretos en tiempo de ejecución usando boto3, cachearlos en memoria entre invocaciones cálidas (warm starts) y conceder permisos ssm:GetParameter o secretsmanager:GetSecretValue con alcance limitado.

+ **Lab 5: API HTTP serverless con Lambda Function URL o API Gateway**
    - **Utilidad real:** Exponer un webhook, un endpoint de integración o un microservicio ligero accesible por HTTP/HTTPS.
    - **Qué aprenderás:** Parsear cabeceras, parámetros de consulta (queryStringParameters) y cuerpos JSON entrantes (body), devolver respuestas HTTP correctas y entender las diferencias de seguridad y autenticación entre una Function URL y API Gateway.

+ **Lab 6: Manejo de timeouts, reintentos y Dead Letter Queue (SQS)**
    - **Utilidad real:** Evitar que eventos fallidos o procesos lentos se pierdan en silencio cuando una dependencia externa falla o tarda más de lo esperado.
    - **Qué aprenderás:** Ajustar timeout y memory_size (y entender su impacto en CPU y coste), ver qué pasa con los reintentos automáticos en invocaciones asíncronas y enviar los mensajes fallidos a una cola SQS DLQ para su análisis posterior.

+ **Lab 7: Lambda dentro de una VPC con Security Groups y VPC Endpoints**
    - **Utilidad real:** Acceder a recursos privados (como una base de datos RDS o servicios internos) manteniendo el aislamiento de red y evitando salidas innecesarias a internet.
    - **Qué aprenderás:** Configurar vpc_config (subnet_ids y security_group_ids), dar a la Lambda permisos para crear interfaces de red (ec2:CreateNetworkInterface, etc.) y entender por qué al meter una Lambda en subredes privadas necesita NAT Gateway o VPC Endpoints para hablar con otros servicios de AWS.

+ **Lab 8: Capas (Lambda Layers) y empaquetado de dependencias externas**
    - **Utilidad real:** Reutilizar librerías de terceros (como requests o clientes específicos) o utilidades compartidas entre varias funciones sin duplicar código ni inflar cada despliegue.
    - **Qué aprenderás:** Crear y versionar un aws_lambda_layer_version, estructurar carpetas (python/ para Python) y decidir cuándo usar una Layer, empaquetar dependencias en el .zip o pasar a un contenedor Docker en ECR.