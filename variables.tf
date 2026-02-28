variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "hub-spoke"
}

# ──────────────────────────────────────────────
# Hub VPC
# ──────────────────────────────────────────────
variable "hub_vpc_cidr" {
  description = "CIDR block for the Hub VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "hub_public_subnets" {
  description = "CIDR blocks for Hub public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "hub_private_subnets" {
  description = "CIDR blocks for Hub private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ──────────────────────────────────────────────
# Spoke VPCs
# ──────────────────────────────────────────────
variable "spokes" {
  description = "Map of Spoke VPC configurations"
  type = map(object({
    cidr            = string
    private_subnets = list(string)
    public_subnets  = list(string)
    environment     = string
  }))
  default = {
    dev = {
      cidr            = "10.1.0.0/16"
      private_subnets = ["10.1.10.0/24", "10.1.11.0/24"]
      public_subnets  = ["10.1.0.0/24", "10.1.1.0/24"]
      environment     = "dev"
    }
    prod = {
      cidr            = "10.2.0.0/16"
      private_subnets = ["10.2.10.0/24", "10.2.11.0/24"]
      public_subnets  = ["10.2.0.0/24", "10.2.1.0/24"]
      environment     = "prod"
    }
  }
}

# ──────────────────────────────────────────────
# Bastion Host
# ──────────────────────────────────────────────
variable "bastion_instance_type" {
  description = "EC2 instance type for Bastion Host"
  type        = string
  default     = "t3.micro"
}

variable "enable_bastion" {
  description = "Whether to deploy a Bastion Host in the Hub VPC"
  type        = bool
  default     = true
}

# ──────────────────────────────────────────────
# Availability Zones
# ──────────────────────────────────────────────
variable "availability_zones" {
  description = "List of AZs to use (must match subnet count)"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}
