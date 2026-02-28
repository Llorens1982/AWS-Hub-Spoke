variable "name" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "spoke_cidrs" {
  type    = list(string)
  default = []
}
