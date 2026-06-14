terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Module      = "10_01_EKS_RBAC_IAM"
    }
  }
}

# Reference existing cluster created in module 07 or 09
# No VPC, no EKS, no bastion created here — this module only adds IAM + access entries
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = var.cluster_state_bucket
    key    = var.cluster_state_key
    region = var.aws_region
  }
}

data "aws_caller_identity" "current" {}
