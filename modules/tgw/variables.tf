variable "name" {
  type = string
}

variable "project_name" {
  type = string
}

variable "hub_vpc_id" {
  type = string
}

variable "hub_subnet_ids" {
  type = list(string)
}

variable "hub_vpc_cidr" {
  type = string
}

variable "hub_route_table_id" {
  type = string
}

variable "spokes" {
  description = "Map of spoke configurations"
  type = map(object({
    vpc_id         = string
    subnet_ids     = list(string)
    vpc_cidr       = string
    route_table_id = string
    environment    = string
  }))
}
