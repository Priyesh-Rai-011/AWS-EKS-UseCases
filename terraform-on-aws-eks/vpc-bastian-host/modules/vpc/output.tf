output "vpc_id" {
  value = aws_vpc.basic-vpc.id
}

output "vpc_cidr_block" {
  value = aws_vpc.basic-vpc.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  value = aws_subnet.database[*].id
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.simple-nat-gateway[*].id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id
}