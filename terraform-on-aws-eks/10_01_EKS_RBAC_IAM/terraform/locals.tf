locals {
  cluster_name = "eks-rbac-${var.environment}"
  vpc_name     = "vpc-rbac-${var.environment}"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "10_01_EKS_RBAC_IAM"
  }
}
