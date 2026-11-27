# vpc.tf

# Red privada aislada para el Lab 09
resource "aws_vpc" "lab09_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "lab09-audit-vpc"
  }
}

# Obtiene las zonas de disponibilidad (AZs) activas en eu-west-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Subred privada A en la primera AZ
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.lab09_vpc.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "lab09-private-subnet-a"
  }
}

# Subred privada B en la segunda AZ (necesario mínimo 2 AZs para Lambda en VPC)
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.lab09_vpc.id
  cidr_block        = "10.20.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "lab09-private-subnet-b"
  }
}

# Tabla de rutas para las subredes privadas (sin salida a internet)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.lab09_vpc.id

  tags = {
    Name = "lab09-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

# Gateway VPC Endpoint para S3: tráfico privado hacia S3 sin pagar NAT Gateway
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.lab09_vpc.id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]

  tags = {
    Name = "lab09-s3-gateway-endpoint"
  }
}

# Gateway VPC Endpoint para DynamoDB: permite a la Lambda en subred privada
# escribir en la tabla DynamoDB por red interna de AWS sin NAT Gateway.
resource "aws_vpc_endpoint" "dynamodb_gateway" {
  vpc_id            = aws_vpc.lab09_vpc.id
  service_name      = "com.amazonaws.eu-west-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]

  tags = {
    Name = "lab09-dynamodb-gateway-endpoint"
  }
}

# Security Group para la Lambda dentro de la VPC
resource "aws_security_group" "lambda_sg" {
  name        = "lab09-lambda-sg"
  description = "Permite trafico de salida desde la Lambda hacia endpoints/servicios"
  vpc_id      = aws_vpc.lab09_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lab09-lambda-sg"
  }
}