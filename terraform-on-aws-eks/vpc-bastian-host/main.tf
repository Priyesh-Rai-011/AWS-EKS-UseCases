module "vpc" {
  source = "./modules/vpc"

  # these two come from root locals.tf
  name        = local.name
  common_tags = local.common_tags

  # these come from root variables.tf
  vpc_name         = "main"
  vpc_cidr_block   = var.vpc_cidr_block
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
}

module "bastion" {
  source = "./modules/bastian"

  name        = local.name
  common_tags = local.common_tags

  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]

  instance_type       = var.bastion_instance_type
  # key_name            = var.bastion_key_name
  # allowed_cidr_blocks = var.bastion_allowed_cidr
}

