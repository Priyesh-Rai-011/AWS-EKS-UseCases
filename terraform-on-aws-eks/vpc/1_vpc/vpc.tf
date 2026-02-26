data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0" # Updated version

  name = "basic-vpc"
  cidr = "10.0.0.0/16"
#   azs  = ["us-east-1a", "us-east-1b"]
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)

  # Public Subnets
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_suffix = "public"
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1" # Important for EKS
  }

  # Private Subnets
  private_subnets       = ["10.0.11.0/24", "10.0.12.0/24"]
  private_subnet_suffix = "private"
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1" # Important for EKS
  }

  enable_nat_gateway = true
#   single_nat_gateway = true

  # Database Subnets
  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  database_subnets                   = ["10.0.21.0/24", "10.0.22.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Owner       = "Priyesh"
    Environment = "dev"
  }
}