terraform {
  backend "s3" {
    bucket         = "learning-remotebackend"
    key            = "terraform-on-aws-eks/vpc/2_vpc_standard/terraform.tfstate"
    region         = "ap-south-1" 
    dynamodb_table = "terraform-dev-state-table"
    encrypt        = true
  }
}

# locals {
#   name         = "eks"
#   common_tags  = {
#     Environment = "dev"
#   }
# }
data "aws_availability_zones" "available" {
  state = "available"
}# so it will auto matically take all the available availability zones in the region and then we can use it to create the subnets in different availability zones for high availability and fault tolerance.

#vpc
resource "aws_vpc" "basic-vpc" {
    cidr_block = var.vpc_cidr_block
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = merge(local.common_tags, {Name = "${local.name}-${var.vpc_name}"})
}

#internet gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.basic-vpc.id

    tags = merge(local.common_tags, {Name = "${local.name}-igw"})
}


#subnetes [public, private, database]

#public subnet
resource "aws_subnet" "public" {
    count = length(var.public_subnets) 
    vpc_id = aws_vpc.basic-vpc.id
    # availability_zone = element(var.availability_zones, count.index)
    availability_zone = element(data.aws_availability_zones.available.names, count.index)
    cidr_block = var.public_subnets[count.index]

    tags = merge(local.common_tags, {Name = "${local.name}-public-subnet-${count.index + 1}", Type = "Public Subnets"})
}
# private subnet
resource "aws_subnet" "private" {
    count = length(var.private_subnets)
    vpc_id = aws_vpc.basic-vpc.id

    cidr_block = var.private_subnets[count.index]
    availability_zone = element(data.aws_availability_zones.available.names, count.index)

    tags = merge(local.common_tags, {Name = "${local.name}-private-subnet-${count.index + 1}", Type = "Private Subnets"})
}
# database subnet
resource "aws_subnet" "database" {
    count = length(var.database_subnets)
    vpc_id = aws_vpc.basic-vpc.id
    cidr_block = var.database_subnets[count.index]
    availability_zone = element(data.aws_availability_zones.available.names, count.index)

    tags = merge(local.common_tags, {Name = "${local.name}-database-subnet-${count.index + 1}", Type = "Database Subnets"})
}

# nat gateway
# why do we have to define elastic ip for nat gateway? and does it talsk to the internet gateway to route the traffic to the internet?
# because nat gateway needs to have a public ip address to route the traffic to the internet gateway and then to the internet. and yes, nat gateway talks to the internet gateway to route the traffic to the internet.
# what is the difference between the ec2 elastic ip and the nat gateway elastic ip? 
# the ec2         - elastic ip is a static public ip address that can be associated with an ec2 instance, 
# while 
# the nat gateway - elastic ip is a static public ip address that is associated with a nat gateway. 

# The nat gateway - elastic ip is used to route traffic from the private subnets to the internet, 
# while 
# the ec2         - elastic ip is used to route traffic to and from an ec2 instance.

# without the elastic ip, the natgtw and ht ec2 instance will not be able to communicate with the internet? how?
# without the elastic ip, the nat gateway and the ec2 instance will not be able to communicate with the internet because they will not have a public ip address to route the traffic to the internet gateway and then to the internet.
# but whan we create a ec2 instance we do get a public ip address, so why do we need an elastic ip for the ec2 instance?
# when we create an ec2 instance, we do get a public ip address, but it is not a static public ip address, it is a dynamic public ip address that can change when the instance is stopped and started.
# so if we want to have a static public ip address for our ec2 instance, we need to associate an elastic ip address with the instance.
# and for the nat gateway, we need to have a static public ip address to route the traffic from the private subnets to the internet, so we need to associate an elastic ip address with the nat gateway.



# nat gateway
# elastic ip for nat gateway
resource "aws_eip" "nat-gateway-eip" {
    count = length(var.public_subnets)
    domain = "vpc"  # this is required for nat gateway elastic ip
    # what is th edifference betweent the domain "vpc" and "standard" for elastic ip? and why do we need to specify the domain for the elastic ip for nat gateway?
    # 


    # what is the difference between the domain "vpc" and vpc = true?
    # the domain "vpc" =  used to specify that the elastic ip is for a nat gateway, 
    # while 
    # the vpc = true   =  used to specify that the elastic ip is for an ec2 instance.
    tags = merge(local.common_tags, {Name = "${local.name}-nat-gateway-eip-${count.index + 1}"})
}
resource "aws_nat_gateway" "simple-nat-gateway" {
    # count = length(var.public_subnets)
    count         = var.vpc_enable_nat_gateway ? (var.vpc_single_nat_gateway ? 1 : length(var.public_subnets)) : 0
    allocation_id = aws_eip.nat-gateway-eip[count.index].id
    subnet_id = aws_subnet.public[count.index].id
    # what is ht edifference between the allocation_id and the subnet_id for the nat gateway?
    # the allocation_id   = the id of the elastic ip that is associated with the nat gateway,
    # while 
    # the subnet_id       = the id of the public subnet that the nat gateway is associated with.
    # it will not be associated with a public subnet to route the traffic to the internet gateway and then to the internet.

    tags = merge(local.common_tags, {Name = "${local.name}-nat-gateway-${count.index + 1}"})
}



# route table
# public subnets - rt
resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.basic-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }#it will route what all traffic to the internet gateway and then to the internet?
    # it will route all the traffic from the public subnets to the internet gateway and then to the internet.
    # if an ec2 instance in the public subnet tries to access the internet, the traffic will be routed to the internet gateway and then to the internet.
    # but if the ec2 isntance have a elactic ip? then the traffic will be routed to the internet gateway and then to the internet, 
    # but the response traffic from the internet will be routed back to the elastic ip and then to the ec2 instance. 
    # not through the internet gateway and then to the ec2 instance, because the elastic ip is associated with the ec2 instance and it will route the traffic to the ec2 instance.

    tags = merge(local.common_tags, {Name = "${local.name}-public-route-table"})
}
# public subnets association - rt association
resource "aws_route_table_association" "public_route_table_association" {
  count = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}


# private subnets - rt
resource "aws_route_table" "private_route_table" {
    vpc_id = aws_vpc.basic-vpc.id
    # count = length(var.private_subnets)
    count = var.vpc_enable_nat_gateway ? (var.vpc_single_nat_gateway ? 1 : length(var.private_subnets)) : 0
    # why can't we use count  = var.vpc_enable_nat_gateway ? (var.vpc_single_nat_gateway ? 1 : length(var.vpc_private_subnets)) : 0
    # we can't use count = var.vpc_enable_nat_gateway ? (var.vpc_single_nat_gateway ? 1 : length(var.vpc_private_subnets)) : 0 because it will not work with the for loop in the route table association resource,

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.simple-nat-gateway[count.index].id
    }
    
    tags = merge(local.common_tags, {Name = "${local.name}-private-route-table-${count.index + 1}"})
    depends_on = [aws_nat_gateway.simple-nat-gateway]
}

# private subnets association - rt association
resource "aws_route_table_association" "private_route_table_association" {
    count = length(var.private_subnets)
    subnet_id      = aws_subnet.private[count.index].id

    route_table_id = var.vpc_single_nat_gateway ? aws_route_table.private_route_table[0].id : aws_route_table.private_route_table[count.index].id
    # route_table_id = aws_route_table.private_route_table[count.index].id
    # why can't we use route_table_id = var.vpc_single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
    # we can't use route_table_id = var.vpc_single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id because it will not work with the for loop in the route table association resource, and it will also not work with the count in the route table resource.
}