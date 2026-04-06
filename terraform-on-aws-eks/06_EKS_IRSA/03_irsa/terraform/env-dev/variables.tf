variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

# ── Paste from: cd 02_eks_cluster && terraform output ─────────────────────────
# variable "oidc_provider_arn" {
#   type        = string
#   description = "From 02_eks_cluster output: oidc_provider_arn"
# }

# variable "oidc_provider_url" {
#   type        = string
#   description = "From 02_eks_cluster output: oidc_provider_url (no https://)"
# }

# ── IRSA binding — must match k8s-manifests exactly ──────────────────────────
variable "namespace" {
  type    = string
  default = "s3-demo"
}

variable "service_account_name" {
  type    = string
  default = "s3-demo-sa"
}