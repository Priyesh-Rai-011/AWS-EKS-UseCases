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

# ── Required by 03_irsa — reads these via terraform_remote_state ──────────────
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider — consumed by 03_irsa module"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without https:// — consumed by 03_irsa module"
  value       = module.eks.oidc_provider_url
}