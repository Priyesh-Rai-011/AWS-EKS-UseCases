terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "learning-remotebackend2"
    key            = "terraform-on-aws-eks/eks-private-nodegroup/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "learning-remotebackend"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {tags = {ManagedBy = "Terraform"}}
}