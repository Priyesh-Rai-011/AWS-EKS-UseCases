locals {
  cluster_name = "eks-eso-${var.environment}"
  vpc_name     = "vpc-${var.environment}"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
