# Lab 4: Consumo seguro de secretos y parámetros (SSM Parameter Store / Secrets Manager)

+ **Lab 4: Consumo seguro de secretos y parámetros (SSM Parameter Store / Secrets Manager)**
    - **Utilidad real:** Conectar una Lambda a APIs externas, bases de datos o servicios de terceros sin dejar contraseñas o tokens escritos en el código ni en variables de entorno planas.
    - **Qué aprenderás:** Recuperar parámetros o secretos en tiempo de ejecución usando boto3, cachearlos en memoria entre invocaciones cálidas (warm starts) y conceder permisos ssm:GetParameter o secretsmanager:GetSecretValue con alcance limitado.