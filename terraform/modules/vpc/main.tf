variable "vpc_name" {
  description = "Nombre de la VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
}

variable "availability_zones" {
  description = "Lista de AZs"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs para subnets públicas"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs para subnets privadas"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway"
  type        = bool
  default     = true
}

variable "transit_gateway_id" {
  description = "ID del Transit Gateway"
  type        = string
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = var.vpc_name
  }
}

# Subnets Públicas
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.vpc_name}-public-${count.index + 1}"
    Type = "Public"
  }
}

# Subnets Privadas
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "${var.vpc_name}-private-${count.index + 1}"
    Type = "Private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# NAT Gateway (opcional)
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? length(var.public_subnet_cidrs) : 0
  domain = "vpc"
  
  tags = {
    Name = "${var.vpc_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? length(var.public_subnet_cidrs) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = {
    Name = "${var.vpc_name}-nat-${count.index + 1}"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.vpc_name}-private-rt-${count.index + 1}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Transit Gateway Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.main.id
  subnet_ids         = aws_subnet.private[*].id
  
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = "${var.vpc_name}-tgw-attachment"
  }
}

# Rutas al TGW desde subnets privadas
resource "aws_route" "private_to_tgw" {
  count                  = length(var.private_subnet_cidrs)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = var.transit_gateway_id
  
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.main]
}

# Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "transit_gateway_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.main.id
}