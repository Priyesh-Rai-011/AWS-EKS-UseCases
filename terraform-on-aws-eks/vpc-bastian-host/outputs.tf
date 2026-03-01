# -------------------------------------------------------------------
# VPC Outputs
# -------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnet_ids
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

# -------------------------------------------------------------------
# Bastion Outputs
# -------------------------------------------------------------------
output "bastion_instance_id" {
  description = "EC2 Instance ID of the bastion host"
  value       = module.bastion.bastion_instance_id
}

output "bastion_security_group_id" {
  description = "Use this SG ID in private instance security groups to allow traffic from bastion only"
  value       = module.bastion.bastion_security_group_id
}

output "ssm_connect_command" {
  description = "Run this in your terminal to SSH into bastion via SSM"
  value       = module.bastion.ssm_connect_command
}
# ```

# ---

# The flow is:
# ```
# module.vpc outputs    → root outputs.tf reads them as module.vpc.xxx
# module.bastion outputs → root outputs.tf reads them as module.bastion.xxx