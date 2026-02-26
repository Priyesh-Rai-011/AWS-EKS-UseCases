terraform {
  backend "s3" {
    bucket         = "learning-remotebackend"
    key            = "terraform-on-aws-eks/vpc/2_vpc_standard/terraform.tfstate"
    region         = "us-east-1" 
    dynamodb_table = "terraform-dev-state-table"
    encrypt        = true
  }
}



