output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.basic-vpc.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets — used by bastion and ALB"
  value       = aws_subnet.public[*].id
}
output "public_subnet_cidrs" {
  description = "value"
  value = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "IDs of private subnets — used by EKS node group"
  value       = aws_subnet.private[*].id
}
output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets — used by EKS PrivateLink SG ingress rule"
  value       = aws_subnet.private[*].cidr_block
}

output "database_subnet_ids" {
  description = "IDs of database subnets — used by RDS"
  value       = aws_subnet.database[*].id
}