terraform {
  backend "s3" {
    bucket         = "learning-remotebackend2"
    key            = "terraform-on-aws-eks/10_01_EKS_RBAC_IAM/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "learning-remotebackend"
    encrypt        = true
  }
}
