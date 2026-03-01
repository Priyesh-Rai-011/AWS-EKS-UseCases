terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "learning-remotebackend"
    key            = "terraform-on-aws-eks/vpc-bastian-host/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-dev-state-table"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}