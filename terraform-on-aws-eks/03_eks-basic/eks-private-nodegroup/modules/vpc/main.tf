# =+=+=+=+=+=+=+=+=+=+=+=+=+=+
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, { Name = "${var.name}-${var.vpc_name}" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.name}-igw" })
}

# Public subnets — host NAT GW and external load balancers
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  cidr_block        = var.public_subnets[count.index]

  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name                                        = "${var.name}-public-subnet-${count.index + 1}"
    Type                                        = "Public Subnets"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# Private subnets — EKS nodes, internal load balancers
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = merge(var.common_tags, {
    Name                                        = "${var.name}-private-subnet-${count.index + 1}"
    Type                                        = "Private Subnets"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# Database subnets — fully isolated, no internet route
resource "aws_subnet" "database" {
  count             = length(var.database_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = merge(var.common_tags, {
    Name = "${var.name}-database-subnet-${count.index + 1}"
    Type = "Database Subnets"
  })
}

# Elastic IPs for NAT gateway(s)
resource "aws_eip" "nat_gateway" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.igw]

  tags = merge(var.common_tags, { Name = "${var.name}-nat-gateway-eip-${count.index + 1}" })
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  allocation_id = aws_eip.nat_gateway[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.igw]

  tags = merge(var.common_tags, { Name = "${var.name}-nat-gateway-${count.index + 1}" })
}


# =========================================================================
# Route tables and associations

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.common_tags, { Name = "${var.name}-public-route-table" })
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnets)) : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.common_tags, { Name = "${var.name}-private-route-table-${count.index + 1}" })

  depends_on = [aws_nat_gateway.main]
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Database route table — no internet route, fully isolated
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.name}-database-route-table" })
}

resource "aws_route_table_association" "database" {
  count          = length(var.database_subnets)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
