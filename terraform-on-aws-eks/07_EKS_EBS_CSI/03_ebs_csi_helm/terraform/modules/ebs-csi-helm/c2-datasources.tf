# Fetch OIDC provider URL from existing EKS cluster — needed for IRSA trust policy
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Extract just the hostname from the OIDC issuer URL (strip https://)
locals {
  oidc_issuer     = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  oidc_issuer_url = replace(local.oidc_issuer, "https://", "")
}

data "aws_iam_openid_connect_provider" "this" {
  url = local.oidc_issuer
}

data "aws_caller_identity" "current" {}
