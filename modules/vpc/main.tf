# ──────────────────────────────────────────────────────────────────────────────
# VPC
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge({ Name = var.name }, var.tags)
}

# ──────────────────────────────────────────────────────────────────────────────
# Internet Gateway
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_internet_gateway" "this" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge({ Name = "${var.name}-igw" }, var.tags)
}

# ──────────────────────────────────────────────────────────────────────────────
# Public Subnets
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge({
    Name = "${var.name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }, var.tags)
}

resource "aws_route_table" "public" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge({ Name = "${var.name}-public-rt" }, var.tags)
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ──────────────────────────────────────────────────────────────────────────────
# NAT Gateway (opcional, solo Hub)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  domain = "vpc"

  tags = merge({ Name = "${var.name}-nat-eip-${count.index}" }, var.tags)
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.this]

  tags = merge({ Name = "${var.name}-nat-${count.index}" }, var.tags)
}

# ──────────────────────────────────────────────────────────────────────────────
# Private Subnets
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge({
    Name = "${var.name}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  }, var.tags)
}

resource "aws_route_table" "private" {
  # Una route table por subnet privada (permite rutas NAT per-AZ o una compartida)
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.this.id

  tags = merge({
    Name = "${var.name}-private-rt-${count.index}"
  }, var.tags)
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? length(var.private_subnets) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ──────────────────────────────────────────────────────────────────────────────
# VPC Flow Logs → CloudWatch
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.name}"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.name}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = merge({ Name = "${var.name}-flow-log" }, var.tags)
}
