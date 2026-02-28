# ──────────────────────────────────────────────────────────────────────────────
# Transit Gateway
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Hub & Spoke Transit Gateway for ${var.project_name}"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = { Name = var.name }
}

# ──────────────────────────────────────────────────────────────────────────────
# TGW Route Tables: Hub (centralizado) y Spokes (aislados)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_ec2_transit_gateway_route_table" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "${var.name}-rt-hub" }
}

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "${var.name}-rt-spokes" }
}

# ──────────────────────────────────────────────────────────────────────────────
# HUB Attachment
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.hub_vpc_id
  subnet_ids         = var.hub_subnet_ids

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = { Name = "${var.name}-attachment-hub" }
}

# Hub attachment → Hub route table
resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

# Hub propaga sus rutas a la route table de spokes
# (para que los spokes puedan alcanzar el Hub/NAT)
resource "aws_ec2_transit_gateway_route_table_propagation" "hub_to_spokes" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# ──────────────────────────────────────────────────────────────────────────────
# SPOKE Attachments
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  for_each = var.spokes

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name        = "${var.name}-attachment-spoke-${each.key}"
    Environment = each.value.environment
  }
}

# Cada spoke → Spoke route table
resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  for_each = var.spokes

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# Cada spoke propaga sus CIDRs a la Hub route table
# (el Hub puede alcanzar todos los spokes)
resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_to_hub" {
  for_each = var.spokes

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

# Ruta default en la Spoke route table → Hub (para salida a internet via NAT del Hub)
resource "aws_ec2_transit_gateway_route" "spoke_default_to_hub" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# ──────────────────────────────────────────────────────────────────────────────
# VPC Route Tables: inyectar rutas TGW en las VPCs
# ──────────────────────────────────────────────────────────────────────────────

# Hub: rutas hacia cada CIDR de spoke via TGW
resource "aws_route" "hub_to_spoke" {
  for_each = var.spokes

  route_table_id         = var.hub_route_table_id
  destination_cidr_block = each.value.vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.hub]
}

# Spokes: ruta default → TGW (salida internet via Hub NAT)
resource "aws_route" "spoke_default_to_tgw" {
  for_each = var.spokes

  route_table_id         = each.value.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}

# Spokes: ruta hacia el Hub CIDR explícita
resource "aws_route" "spoke_to_hub" {
  for_each = var.spokes

  route_table_id         = each.value.route_table_id
  destination_cidr_block = var.hub_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}
