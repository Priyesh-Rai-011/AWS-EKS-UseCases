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
    key            = "terraform-on-aws-eks/09-secrets-02-eso/terraform.tfstate"
    region         = "us-east-1"

    dynamodb_table = "learning-remotebackend"
    encrypt        = true
  }
}
