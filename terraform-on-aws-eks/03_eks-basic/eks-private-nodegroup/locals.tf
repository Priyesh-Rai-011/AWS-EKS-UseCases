locals {
  name         = var.environment
  cluster_name = "eks-${local.name}"
  vpc_name     = "vpc-${local.name}"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}