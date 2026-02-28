# ──────────────────────────────────────────────────────────────────────────────
# HUB VPC
# ──────────────────────────────────────────────────────────────────────────────
module "hub_vpc" {
  source = "./modules/vpc"

  name               = "${var.project_name}-hub"
  vpc_cidr           = var.hub_vpc_cidr
  availability_zones = var.availability_zones
  public_subnets     = var.hub_public_subnets
  private_subnets    = var.hub_private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true  # En prod pon false para HA

  tags = {
    Role = "hub"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# SPOKE VPCs
# ──────────────────────────────────────────────────────────────────────────────
module "spoke_vpc" {
  for_each = var.spokes
  source   = "./modules/vpc"

  name               = "${var.project_name}-spoke-${each.key}"
  vpc_cidr           = each.value.cidr
  availability_zones = var.availability_zones
  public_subnets     = each.value.public_subnets
  private_subnets    = each.value.private_subnets

  # Los spokes usan el Hub como salida a internet (via TGW → Hub NAT)
  enable_nat_gateway = false
  single_nat_gateway = false

  tags = {
    Role        = "spoke"
    Environment = each.value.environment
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# TRANSIT GATEWAY + ATTACHMENTS
# ──────────────────────────────────────────────────────────────────────────────
module "tgw" {
  source = "./modules/tgw"

  name         = "${var.project_name}-tgw"
  project_name = var.project_name

  # Hub
  hub_vpc_id         = module.hub_vpc.vpc_id
  hub_subnet_ids     = module.hub_vpc.private_subnet_ids
  hub_vpc_cidr       = var.hub_vpc_cidr
  hub_route_table_id = module.hub_vpc.private_route_table_id

  # Spokes — pasamos los outputs del módulo spoke como mapa
  spokes = {
    for k, v in var.spokes : k => {
      vpc_id         = module.spoke_vpc[k].vpc_id
      subnet_ids     = module.spoke_vpc[k].private_subnet_ids
      vpc_cidr       = v.cidr
      route_table_id = module.spoke_vpc[k].private_route_table_id
      environment    = v.environment
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# BASTION HOST (Hub)
# ──────────────────────────────────────────────────────────────────────────────
module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "./modules/ec2-bastion"

  name          = "${var.project_name}-bastion"
  vpc_id        = module.hub_vpc.vpc_id
  subnet_id     = module.hub_vpc.private_subnet_ids[0]
  instance_type = var.bastion_instance_type
}

# ──────────────────────────────────────────────────────────────────────────────
# SECURITY GROUPS
# ──────────────────────────────────────────────────────────────────────────────
module "hub_security_groups" {
  source = "./modules/security-groups"

  name     = "${var.project_name}-hub"
  vpc_id   = module.hub_vpc.vpc_id
  vpc_cidr = var.hub_vpc_cidr

  spoke_cidrs = [for k, v in var.spokes : v.cidr]
}
