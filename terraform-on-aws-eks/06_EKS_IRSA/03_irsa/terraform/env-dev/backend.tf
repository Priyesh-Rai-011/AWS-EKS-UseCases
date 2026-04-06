# # terraform {
#   backend "s3" {
#     bucket         = "your-tfstate-bucket"
#     key            = "dev/03-irsa/terraform.tfstate"
#     region         = "ap-south-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }




terraform {
  # required_version = ">= 1.5.0"
  # required_providers {
  #   aws = {
  #     source  = "hashicorp/aws"
  #     version = "~> 5.0"
  #   }
  # }

  backend "s3" {
    bucket         = "learning-remotebackend2"
    key            = "terraform-on-aws-eks/irsa/terraform.tfstate"  # ← only this changes
    region         = "ap-south-1"

    dynamodb_table = "learning-remotebackend"
    encrypt        = true
  }
# }

# provider "aws" {
#   region = var.aws_region
#   default_tags { tags = { ManagedBy = "Terraform" } }
}