locals {
  name         = "eks-irsa-${var.environment}"
  cluster_name = "eks-irsa-${var.environment}"
  vpc_name     = "vpc-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = "ums-ebs-csi-irsa"
    ManagedBy   = "Terraform"
  }
}
