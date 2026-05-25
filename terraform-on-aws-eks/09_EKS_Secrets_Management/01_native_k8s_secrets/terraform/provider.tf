provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = "pulseauth-secrets"
    }
  }
}
