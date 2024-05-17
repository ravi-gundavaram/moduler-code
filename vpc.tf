module "label_vpc" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "vpc"
  attributes = ["main"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = module.label_vpc.tags
}

# Correctly using the hashicorp/subnets/cidr module as per its documentation
module "subnets_addrs" {
  source  = "hashicorp/subnets/cidr"
  version = ">= 1.0.0"

  base_cidr_block = var.vpc_cidr
  networks = [
    {
      name    = "public"
      new_bits = 4
      netnum  = 0
    },
    {
      name    = "private"
      new_bits = 4  
      netnum  = 1
    }
  ]
}

resource "aws_subnet" "public_subnet" {
  for_each = {for k, v in module.subnets_addrs.network_cidr_blocks : k => v if k == "public" }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "${module.label_vpc.id}-${each.key}" 
  }
}

resource "aws_subnet" "private_subnet" {
  for_each = {for k, v in module.subnets_addrs.network_cidr_blocks : k => v if k == "private" }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "${module.label_vpc.id}-${each.key}"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_route_table_assoc" {
  for_each = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

data "aws_availability_zones" "available" {}
