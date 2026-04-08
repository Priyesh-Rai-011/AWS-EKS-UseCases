# =+=+=+=+=+=+=+=+=+=+=+=+=+=+

module "vpc" {
  source = "./modules/01_vpc"

  # Matching vpc/variables.tf exactly
  name                    = local.name
  vpc_name                = local.vpc_name
  vpc_cidr_block          = var.vpc_cidr_block

  public_subnets          = var.public_subnets
  private_subnets         = var.private_subnets
  database_subnets        = var.database_subnets
  
  enable_nat_gateway      = var.enable_nat_gateway
  single_nat_gateway      = var.single_nat_gateway
  
  common_tags             = local.common_tags
}

module "eks" {
  source = "./modules/02_eks"

  # Matching eks/variables.tf exactly
  cluster_name            = local.cluster_name
  cluster_version         = var.cluster_version

  vpc_id                  = module.vpc.vpc_id
  
  public_subnet_ids       = module.vpc.public_subnet_ids
  public_subnet_cidrs     = module.vpc.public_subnet_cidrs

  private_subnet_ids      = module.vpc.private_subnet_ids
  private_subnet_cidrs    = module.vpc.private_subnet_cidrs

  endpoint_public_access  = var.endpoint_public_access
  endpoint_private_access = var.endpoint_private_access
  enable_cluster_logging  = var.enable_cluster_logging


  bastion_role_arn = module.bastion.bastion_role_arn


  tags = local.common_tags
}

module "bastion" {
  source = "./modules/03_bastion"

  # Matching bastion/variables.tf exactly
  name          = "${local.name}-bastion"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnet_ids[0]
  instance_type = var.bastion_instance_type

  aws_region    = var.aws_region
  cluster_name  = local.cluster_name
  common_tags   = local.common_tags
}