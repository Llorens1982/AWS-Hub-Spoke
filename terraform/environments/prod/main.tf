terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "tu-bucket-terraform-state"
    key            = "hub-spoke/prod/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "Production"
      Project     = "HubSpoke"
      ManagedBy   = "Terraform"
    }
  }
}

# Transit Gateway
module "transit_gateway" {
  source = "../../modules/transit-gateway"
  
  name                            = "hub-spoke-tgw"
  description                     = "Transit Gateway para arquitectura Hub-Spoke"
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
}

# Hub VPC - Servicios Compartidos
module "hub_vpc" {
  source = "../../modules/vpc"
  
  vpc_name            = "hub-vpc"
  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = ["eu-west-1a", "eu-west-1b"]
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = false
  
  enable_vpc_endpoints = true
  vpc_endpoints = ["ssm", "ssmmessages", "ec2messages", "s3"]
  
  transit_gateway_id = module.transit_gateway.id
}

# Spoke VPC - Production
module "spoke_prod_vpc" {
  source = "../../modules/vpc"
  
  vpc_name            = "spoke-prod-vpc"
  vpc_cidr            = "10.1.0.0/16"
  availability_zones  = ["eu-west-1a", "eu-west-1b"]
  
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  
  enable_nat_gateway = false  # Usa NAT del Hub
  
  transit_gateway_id = module.transit_gateway.id
}

# Spoke VPC - Development
module "spoke_dev_vpc" {
  source = "../../modules/vpc"
  
  vpc_name            = "spoke-dev-vpc"
  vpc_cidr            = "10.2.0.0/16"
  availability_zones  = ["eu-west-1a", "eu-west-1b"]
  
  public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24"]
  private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24"]
  
  enable_nat_gateway = false  # Usa NAT del Hub
  
  transit_gateway_id = module.transit_gateway.id
}

# TGW Route Tables
resource "aws_ec2_transit_gateway_route_table" "hub" {
  transit_gateway_id = module.transit_gateway.id
  
  tags = {
    Name = "hub-route-table"
  }
}

resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = module.transit_gateway.id
  
  tags = {
    Name = "spokes-route-table"
  }
}

# Associations
resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = module.hub_vpc.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke_prod" {
  transit_gateway_attachment_id  = module.spoke_prod_vpc.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke_dev" {
  transit_gateway_attachment_id  = module.spoke_dev_vpc.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

# Propagations - Spokes pueden ver el Hub
resource "aws_ec2_transit_gateway_route_table_propagation" "spokes_to_hub" {
  transit_gateway_attachment_id  = module.hub_vpc.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

# Propagations - Hub puede ver los Spokes
resource "aws_ec2_transit_gateway_route_table_propagation" "hub_to_prod" {
  transit_gateway_attachment_id  = module.spoke_prod_vpc.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "hub_to_dev" {
  transit_gateway_attachment_id  = module.spoke_dev_vpc.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

# Bastion Host en Hub VPC
module "bastion" {
  source = "../../modules/bastion"
  
  vpc_id            = module.hub_vpc.vpc_id
  subnet_id         = module.hub_vpc.public_subnet_ids[0]
  instance_type     = "t3.micro"
  key_name          = var.key_pair_name
  allowed_cidr_blocks = ["0.0.0.0/0"]  # Restringir en producción
}