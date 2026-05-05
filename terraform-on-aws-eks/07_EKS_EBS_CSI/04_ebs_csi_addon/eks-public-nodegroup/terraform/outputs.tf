output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Run after terraform apply to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "bastion_instance_id" {
  value = module.bastion.bastion_instance_id
}

output "ssm_connect_command" {
  description = "Connect to bastion via SSM Session Manager"
  value       = module.bastion.ssm_connect_command
}

output "ums_app_role_arn" {
  description = "IAM role for ums-app pods — attach to ServiceAccount via Pod Identity"
  value       = module.eks.ums_app_role_arn
}

output "secret_arns" {
  description = "Map of logical key -> Secrets Manager ARN"
  value       = module.secrets.secret_arns
}

output "secret_names" {
  description = "Map of logical key -> Secrets Manager secret name"
  value       = module.secrets.secret_names
}
