# Lab 7: Lambda dentro de una VPC con Security Groups y VPC Endpoints

+ **Lab 7: Lambda dentro de una VPC con Security Groups y VPC Endpoints**
    - **Utilidad real:** Acceder a recursos privados (como una base de datos RDS o servicios internos) manteniendo el aislamiento de red y evitando salidas innecesarias a internet.
    - **Qué aprenderás:** Configurar vpc_config (subnet_ids y security_group_ids), dar a la Lambda permisos para crear interfaces de red (ec2:CreateNetworkInterface, etc.) y entender por qué al meter una Lambda en subredes privadas necesita NAT Gateway o VPC Endpoints para hablar con otros servicios de AWS.