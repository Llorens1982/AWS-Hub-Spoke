variable "aws_region" {
  description = "Región AWS"
  type        = string
  default     = "eu-west-1"
}

variable "key_pair_name" {
  description = "Nombre del key pair para EC2"
  type        = string
}

variable "environment" {
  description = "Nombre del entorno"
  type        = string
  default     = "production"
}