locals {
  name = "eks-irsa-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = "eks-irsa-demo"
    ManagedBy   = "terraform"
  }
}