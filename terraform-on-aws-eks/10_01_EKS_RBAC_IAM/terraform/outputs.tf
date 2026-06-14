output "cluster_name" {
  value = module.eks.cluster_name
}

output "ssm_connect_command" {
  description = "Connect to bastion via SSM"
  value       = module.bastion.ssm_connect_command
}

output "kubectl_config_command" {
  description = "Run this to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.aws_region}"
}

output "ecr_repository_url" {
  description = "Push PulseAuth image here before deploying"
  value       = module.ecr.repository_url
}

output "eso_irsa_role_arn" {
  description = "Paste into 05_test_workloads/pulseauth/serviceaccount.yaml"
  value       = module.eso_iam.role_arn
}

output "persona_role_arns" {
  description = "STS assume-role ARNs for each persona (use in 06_validation scripts)"
  value       = module.rbac_personas.role_arns
}

output "frontend_bucket_name" {
  description = "Run: aws s3 sync dist/pulseauth/ s3://<bucket>/"
  value       = module.frontend_s3.bucket_name
}

output "frontend_website_url" {
  description = "Angular app endpoint after s3 sync"
  value       = module.frontend_s3.website_url
}

output "postgres_secret_name" {
  description = "Seed this via: aws secretsmanager put-secret-value --secret-id <name>"
  value       = module.secrets_manager.postgres_secret_name
}
