data "aws_availability_zones" "available" {
  state = "available"
}

# vpc
resource "aws_vpc" "basic-vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, { Name = "${var.name}-${var.vpc_name}" })

}

# internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.basic-vpc.id

  tags = merge(var.common_tags, { Name = "${var.name}-igw" })
}

# subnets [public, private, database]

# public subnet
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.basic-vpc.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  cidr_block        = var.public_subnets[count.index]

  map_public_ip_on_launch = true
#   map_public_ip_on_launch = true
# what does this mean?
# it means that when an instance is launched in this subnet, it will automatically get a public IP address assigned to it. This is important for public subnets because instances in public subnets need to be able to communicate with the internet, and having a public IP address allows them to do so.
# is it elastic ip?
# no, it is not an elastic IP. It is a public IP address that is automatically

  tags = merge(var.common_tags, {Name = "${var.name}-public-subnet-${count.index + 1}", Type = "Public Subnets"})
}

# private subnet
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)   # fix: length not leanth
  vpc_id            = aws_vpc.basic-vpc.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = merge(var.common_tags, {Name = "${var.name}-private-subnet-${count.index + 1}", Type = "Private Subnets"})
}

# database subnet
resource "aws_subnet" "database" {
  count             = length(var.database_subnets)
  vpc_id            = aws_vpc.basic-vpc.id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = merge(var.common_tags, {Name = "${var.name}-database-subnet-${count.index + 1}", Type = "Database Subnets"})
}

# nat gateway
# elastic ip for nat gateway
resource "aws_eip" "nat-gateway-eip" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.igw]

  tags = merge(var.common_tags, { Name = "${var.name}-nat-gateway-eip-${count.index + 1}" })
}

# nat gateway
resource "aws_nat_gateway" "simple-nat-gateway" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  allocation_id = aws_eip.nat-gateway-eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.igw]

  tags = merge(var.common_tags, { Name = "${var.name}-nat-gateway-${count.index + 1}" })
}





# =========================================================================
# route tables and associations


# public subnet - rt
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.basic-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.common_tags, { Name = "${var.name}-public-route-table" })
}
# public subnet - rt association
resource "aws_route_table_association" "public_route_table_association" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}
# --------------------------------------------------------------------------
# private subnet - rt
resource "aws_route_table" "private_route_table" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnets)) : 0
  vpc_id = aws_vpc.basic-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.simple-nat-gateway[count.index].id
  }

  tags = merge(var.common_tags, { Name = "${var.name}-private-route-table-${count.index + 1}" })

  depends_on = [aws_nat_gateway.simple-nat-gateway]
}
# private subnet - rt association
resource "aws_route_table_association" "private_route_table_association" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private_route_table[0].id : aws_route_table.private_route_table[count.index].id
}
# -------------------------------------------------------------------------
# database subnet - rt (no internet route, fully isolated)
resource "aws_route_table" "database_route_table" {
  vpc_id = aws_vpc.basic-vpc.id

  tags = merge(var.common_tags, { Name = "${var.name}-database-route-table" })
}
# database subnet - rt association
resource "aws_route_table_association" "database_route_table_association" {
  count          = length(var.database_subnets)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database_route_table.id
}