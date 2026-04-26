locals {
  name         = "eks-helm-${var.environment}"
  cluster_name = "eks-helm-${var.environment}"
  vpc_name     = "vpc-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = "ums-ebs-csi"
    ManagedBy   = "Terraform"
  }
}
