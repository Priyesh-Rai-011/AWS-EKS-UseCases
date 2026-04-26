terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "learning-remotebackend2"
    key            = "terraform-on-aws-eks/07-ebs-csi/helm/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "learning-remotebackend"
    encrypt        = true
  }
}
