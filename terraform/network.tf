# vpc
resource "aws_vpc" "worth_vpc" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "worth_tech_test"
  }
}

# subnets
resource "aws_subnet" "worth_public_subnet" {
  vpc_id            = aws_vpc.worth_vpc.id
  cidr_block        = local.public_subnet_cidr
  availability_zone = local.availability_zone

  map_public_ip_on_launch = true

  tags = {
    Name = "worth_public"
  }
}

resource "aws_subnet" "worth_private_subnet" {
  vpc_id            = aws_vpc.worth_vpc.id
  cidr_block        = local.private_subnet_cidr
  availability_zone = local.availability_zone

  map_public_ip_on_launch = true

  tags = {
    Name = "worth_private"
  }
}

# IGW
resource "aws_internet_gateway" "worth_igw" {
  vpc_id = aws_vpc.worth_vpc.id

  tags = {
    Name = "worth_igw"
  }
}

# public route table and association
resource "aws_route_table" "worth_public_rt" {
  vpc_id = aws_vpc.worth_vpc.id

  tags = {
    Name = "worth_public"
  }
}

resource "aws_route_table_association" "worth_public_rt_association" {
  subnet_id      = aws_subnet.worth_public_subnet.id
  route_table_id = aws_route_table.worth_public_rt.id
}

# public routing table routes
resource "aws_route" "worth_public_rt_default" {
  route_table_id         = aws_route_table.worth_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.worth_igw.id
}

# private route table and association
resource "aws_route_table" "worth_private_rt" {
  vpc_id = aws_vpc.worth_vpc.id

  tags = {
    Name = "worth_private"
  }
}

resource "aws_route_table_association" "worth_private_rt_association" {
  subnet_id      = aws_subnet.worth_private_subnet.id
  route_table_id = aws_route_table.worth_private_rt.id
}

# private routing table routes
resource "aws_route" "worth_private_rt_default" {
  # This would normally be a NAT gateway to allow the servers access to be updated
  # But NAT gateways appear to accrue a cost whether you're using it or not
  route_table_id         = aws_route_table.worth_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.worth_igw.id
}
