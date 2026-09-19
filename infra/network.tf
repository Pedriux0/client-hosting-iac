#AZ remember to use at least 2 to guarrante resilence 
data "aws_availability_zones" "available" {
  state = "available"
}

#REMEMBER THAT THOSE PORTS SHOULD BE CLOSED IF NOT NEEDED.
locals {
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
}


resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

#PUblic subnets - internet facing
resource "aws_subnet" "public" {
  count = length(local.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

#Private subnets - internal facing
resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.project_name}-private-${local.azs[count.index]}"
    Tier = "private"
  }
}

#Public router table - config route table to internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id

  }

  tags = {
    Name = "${var.project_name}-public-route-table"
  }
}

#Private route table - No deault unless NAT is enable 

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-private-route-table"
  }
}

resource "aws_route_table_association" "public" {

  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

// NAT GATEAWAY - disable not needed (YET)
// REMEMBER THAT IF PRIVATE AND CONNECT TO INTERNET ITS GONNA COST
