# =+=+=+=+=+=+=+=+=+=+=+=+=+=+

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
  description = "Run this after terraform apply to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL — use this in your pod image field"
  value       = module.ecr.repository_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider — consumed by IRSA modules"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without https:// — used as condition key in trust policy"
  value       = module.eks.oidc_provider_url
}

output "eso_role_arn" {
  description = "IAM role ARN for the External Secrets Operator — annotate the ESO service account with this"
  value       = module.eso_iam.eso_role_arn
}
