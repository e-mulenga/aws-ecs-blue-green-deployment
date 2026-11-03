# Private AWS API access for Fargate tasks that sit in the Landing Zone private subnets.
# The Landing Zone has no NAT gateway, so these endpoints are what lets tasks pull images and
# write logs. An endpoint is created ONLY when the VPC does not already have one for that service.

locals {
  gateway_services   = ["s3", "dynamodb"]
  interface_services = concat(["ecr.api", "ecr.dkr", "logs"], var.enable_sqs ? ["sqs"] : [])
  all_services       = concat(local.gateway_services, local.interface_services)
}

# Route tables are not exported by the Landing Zone: resolve them from the private subnets.
data "aws_route_table" "private" {
  for_each  = toset(var.private_subnet_ids)
  subnet_id = each.value
}

locals {
  missing_gateway   = var.create_endpoints ? local.gateway_services : []
  missing_interface = var.create_endpoints ? local.interface_services : []
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(var.create_endpoints ? local.missing_gateway : [])

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = distinct([for rt in data.aws_route_table.private : rt.id])

  tags = {
    Name = "${var.name_prefix}-${each.key}"
  }
}

resource "aws_security_group" "endpoints" {
  count = var.create_endpoints && length(local.missing_interface) > 0 ? 1 : 0

  name        = "${var.name_prefix}-vpc-endpoints"
  description = "HTTPS from the VPC to the interface endpoints"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-vpc-endpoints"
  }
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  count = length(aws_security_group.endpoints)

  security_group_id = aws_security_group.endpoints[0].id
  description       = "HTTPS from the VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.create_endpoints ? local.missing_interface : [])

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]

  tags = {
    Name = "${var.name_prefix}-${each.key}"
  }
}
