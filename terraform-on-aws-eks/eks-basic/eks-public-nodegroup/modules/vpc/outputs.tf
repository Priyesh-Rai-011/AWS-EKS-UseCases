# =+=+=+=+=+=+=+=+=+=+=+=+=+=+
# --- VPC Outputs ---

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.basic-vpc-public-nodegroup.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.basic-vpc-public-nodegroup.cidr_block
}

# --- Subnet Outputs ---

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public-subnet[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private-subnet[*].id
}

output "database_subnet_ids" {
  description = "List of IDs of database subnets"
  value       = aws_subnet.database-subnet[*].id
}

# --- Gateway Outputs ---

output "nat_gateway_public_ips" {
  description = "List of public Elastic IP addresses created for NAT Gateways"
  value       = aws_eip.nat-gateway-eip[*].public_ip
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.basic-igw-public-nodegroup.id
}

# --- Route Table Outputs (Useful for troubleshooting) ---

output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.public-route-table.id
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = aws_route_table.private-route-table[*].id
}