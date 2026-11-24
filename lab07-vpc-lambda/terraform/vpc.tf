# ==========================================
# 1. VPC Y RED PRIVADA
# ==========================================

# Definimos la VPC
resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "lab7-vpc"
  }
}

# Subredes Privadas (se requieren al menos 2 AZs para alta disponibilidad de Lambda en VPC)
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "lab7-subnet-private-a"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "lab7-subnet-private-b"
  }
}

# Tabla de rutas para las subredes privadas (sin Internet Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  tags = {
    Name = "lab7-private-rt"
  }
}

# Asociamos las subredes privadas a la tabla de rutas
resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

# ==========================================
# 2. VPC ENDPOINT (GATEWAY) PARA S3
# ==========================================

# Permite el tráfico privado desde la VPC hacia S3 sin NAT Gateway ni internet.
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.lab_vpc.id
  service_name = "com.amazonaws.eu-west-1.s3"
  # Tipo Gateway (gratuito, se adjunta a la Route Table)
  vpc_endpoint_type = "Gateway"
  
  # Adjuntamos la ruta en la tabla de rutas de subredes privadas
  route_table_ids = [aws_route_table.private_rt.id]

  tags = {
    Name = "lab7-s3-gateway-endpoint"
  }
}

# ==========================================
# 3. SECURITY GROUP PARA LA LAMBDA
# ==========================================

# Permite tráfico de salida (necesario para comunicarse con S3 y AWS)
resource "aws_security_group" "lambda_sg" {
  name        = "lab7-lambda-sg"
  description = "Security Group para Lambda dentro de la VPC"
  vpc_id      = aws_vpc.lab_vpc.id

  # Salida permitida a cualquier destino (necesario para alcanzar los endpoints)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Todos los protocolos
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Entrada (normalmente no se necesita para lambdas que actúan como clientes,
  # a menos que sean invocadas por otros recursos dentro de la VPC)
  # ingress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = [aws_vpc.lab_vpc.cidr_block] # Solo tráfico interno de la VPC
  # }

  tags = {
    Name = "lab7-lambda-sg"
  }
}