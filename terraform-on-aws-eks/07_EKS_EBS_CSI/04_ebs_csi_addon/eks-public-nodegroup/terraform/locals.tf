locals {
  name         = "eks-public-${var.environment}"
  cluster_name = "eks-public-${var.environment}"
  vpc_name     = "vpc-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = "ums-ebs-csi"
    ManagedBy   = "Terraform"
  }
}
