locals {
  name         = "eks-${var.environment}"
  cluster_name = "eks-${var.environment}"
  vpc_name     = "vpc-${var.environment}"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}