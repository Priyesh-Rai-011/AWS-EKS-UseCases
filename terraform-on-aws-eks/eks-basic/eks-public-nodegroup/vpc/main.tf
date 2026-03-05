# =+=+=+=+=+=+=+=+=+=+=+=+=+=+
 data "aws_availability_zones" "available" {
    state = "available" 
}

# vpc

resource "aws_vpc" "basic-vpc-public-nodegroup" {
    cidr_block = var.vpc_cidr

    enable_dns_hostnames = true
    enable_dns_support   = true

    tags = {
        "Name" = "${var.name}-vpc"
    }
}

# internet gateway
resource "aws_internet_gateway" "basic-igw-public-nodegroup" {
    vpc_id = aws_vpc.basic-vpc-public-nodegroup.id

    tags = merge(var.common_tags, { Name = "${var.name}-igw" })
}

# subnets [public, private, database]

# public subnet
resource "aws_subnet" "public-subnet" {
    count                   = length(var.public_subnets)
    vpc_id                  = aws_vpc.basic-vpc-public-nodegroup.id
    availability_zone       = element(data.aws_availability_zones.available.names, count.index)
    cidr_block              = var.public_subnets[count.index]

    map_public_ip_on_launch = var.map_public_ip_on_launch

    tags = merge(var.common_tags, {Name = "${var.name}-public-subnet-${count.index + 1}", Type = "Public Subnets"})
}

# private subnet
resource "aws_subnet" "private-subnet" {
    count             = length(var.private_subnets)
    vpc_id            = aws_vpc.basic-vpc-public-nodegroup.id
    availability_zone = element(data.aws_availability_zones.available.names, count.index)
    cidr_block        = var.private_subnets[count.index]

    tags = merge(var.common_tags, {Name = "${var.name}-private-subnet-${count.index + 1}", Type = "Private Subnets"})
}

# database subnet
resource "aws_subnet" "database-subnet" {
    count             = length(var.database_subnets)
    vpc_id            = aws_vpc.basic-vpc-public-nodegroup.id
    availability_zone = element(data.aws_availability_zones.available.names, count.index)
    cidr_block        = var.database_subnets[count.index]

    tags = merge(var.common_tags, {Name = "${var.name}-database-subnet-${count.index + 1}", Type = "Database Subnets"})
}



# nat gateway

# elastic ip for nat gateway
resource "aws_eip" "nat-gateway-eip" {
    count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
    domain = "vpc"

    depends_on = [ aws_internet_gateway.basic-igw-public-nodegroup ]

    tags = merge(var.common_tags, { Name = "${var.name}-nat-gateway-eip" })
}

# nat gateway
resource "aws_nat_gateway" "simple-nat-gateway" {
    count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
    allocation_id = aws_eip.nat-gateway-eip[count.index].id
    subnet_id     = aws_subnet.public-subnet[count.index].id

    depends_on = [ aws_internet_gateway.basic-igw-public-nodegroup ]

    tags = merge(var.common_tags, { Name = "${var.name}-nat-gateway" })
}





# =========================================================================
# route tables and associations


# public subnet - rt
resource "aws_route_table" "public-route-table" {
    vpc_id = aws_vpc.basic-vpc-public-nodegroup.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.basic-igw-public-nodegroup.id
    }

    tags = merge(var.common_tags, { Name = "${var.name}-public-route-table" })
}
# public subnet - rt association
resource "aws_route_table_association" "public-route-table-association" {
    count          = length(var.public_subnets)
    subnet_id      = aws_subnet.public-subnet[count.index].id
    route_table_id = aws_route_table.public-route-table.id
}
# --------------------------------------------------------------------------
# private subnet - rt
resource "aws_route_table" "private-route-table" {
    count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnets)) : 0
    vpc_id = aws_vpc.basic-vpc-public-nodegroup.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.name[count.index].id
    }

    tags = merge(var.common_tags, { Name = "${var.name}-private-route-table" })

    depends_on = [ aws_nat_gateway.simple-nat-gateway ]
}
# private subnet - rt association
resource "aws_route_table_association" "private-route-table-association" {
    count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnets)) : 0
    subnet_id = aws_subnet.private-subnet[count.index].id
    route_table_id = aws_route_table.private-route-table[count.index].id
}
# -------------------------------------------------------------------------
# database subnet - rt (no internet routs, fully isolated)
resource "aws_route_table" "database-route-table" {
    vpc_id = aws_vpc.basic-vpc-public-nodegroup.id

    tags = merge(var.common_tags, { Name = "${var.name}-database-route-table" })
}
resource "aws_route_table_association" "database-route-table-association" {
    count = length(var.database_subnets)
    subnet_id = aws_subnet.database-subnet[count.index].id
    route_table_id = aws_route_table.database-route-table.id
}