resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "Security group for Bastion Host — SSM only, no inbound SSH"
  vpc_id      = var.vpc_id

  # Sin reglas de entrada SSH: acceso exclusivo via SSM
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-bastion-sg" }
}

resource "aws_security_group" "shared_services" {
  name        = "${var.name}-shared-services-sg"
  description = "Security group for shared services in Hub"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow traffic from all Spoke VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.spoke_cidrs
  }

  ingress {
    description = "Allow traffic within Hub VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-shared-services-sg" }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "Security group for application tier"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from Hub"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "HTTP from Hub"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-app-sg" }
}
