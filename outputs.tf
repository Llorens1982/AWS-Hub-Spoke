output "hub_vpc_id" {
  description = "Hub VPC ID"
  value       = module.hub_vpc.vpc_id
}

output "hub_private_subnets" {
  description = "Hub private subnet IDs"
  value       = module.hub_vpc.private_subnet_ids
}

output "hub_public_subnets" {
  description = "Hub public subnet IDs"
  value       = module.hub_vpc.public_subnet_ids
}

output "spoke_vpc_ids" {
  description = "Map of Spoke VPC IDs"
  value       = { for k, v in module.spoke_vpc : k => v.vpc_id }
}

output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = module.tgw.tgw_id
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN"
  value       = module.tgw.tgw_arn
}

output "bastion_instance_id" {
  description = "Bastion Host EC2 instance ID (use SSM to connect)"
  value       = var.enable_bastion ? module.bastion[0].instance_id : null
}
