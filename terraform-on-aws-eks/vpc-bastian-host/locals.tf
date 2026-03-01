locals {
  name = "eks"

  common_tags = {
    Environment = var.environment
    Project     = "terraform-on-aws-eks"
    ManagedBy   = "terraform"
  }
}