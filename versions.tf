terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Estos valores se inyectan via -backend-config o variables de entorno
    # Ejemplo: terraform init -backend-config="bucket=my-tfstate-bucket"
    key            = "hub-spoke/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Repository  = "aws-hub-spoke"
      Environment = "shared"
    }
  }
}
