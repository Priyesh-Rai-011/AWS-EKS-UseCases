data "aws_caller_identity" "current" {}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  name           = local.cluster_name
  vpc_name       = local.vpc_name
  vpc_cidr_block = var.vpc_cidr_block

  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  common_tags = local.common_tags
}

# ── EKS ───────────────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id = module.vpc.vpc_id

  public_subnet_ids   = module.vpc.public_subnet_ids
  public_subnet_cidrs = module.vpc.public_subnet_cidrs

  private_subnet_ids   = module.vpc.private_subnet_ids
  private_subnet_cidrs = module.vpc.private_subnet_cidrs

  endpoint_public_access  = var.endpoint_public_access
  endpoint_private_access = var.endpoint_private_access
  enable_cluster_logging  = var.enable_cluster_logging

  bastion_role_arn = module.bastion.bastion_role_arn

  tags = local.common_tags
}

# ── BASTION ───────────────────────────────────────────────────────────────────
module "bastion" {
  source = "./modules/bastion"

  name          = "${local.cluster_name}-bastion"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnet_ids[0]
  instance_type = var.bastion_instance_type

  aws_region   = var.aws_region
  cluster_name = local.cluster_name
  common_tags  = local.common_tags
}

# ── ECR ───────────────────────────────────────────────────────────────────────
module "ecr" {
  source = "./modules/ecr"

  repository_name = var.ecr_repository_name
  common_tags     = local.common_tags
}

# ── SECRETS MANAGER ───────────────────────────────────────────────────────────
# Provisions blank secret shells — seed real values via CLI after apply
module "secrets_manager" {
  source = "./modules/secrets_manager"

  cluster_name = local.cluster_name
  environment  = var.environment
  common_tags  = local.common_tags
}

# ── ESO IRSA ROLE ─────────────────────────────────────────────────────────────
# pulseauth-sa in backend-prod assumes this role to pull secrets from SM
module "eso_iam" {
  source = "./modules/eso_iam"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  secret_arns       = module.secrets_manager.secret_arns
  environment       = var.environment
  aws_region        = var.aws_region
  tags              = local.common_tags
}

# ── RBAC IAM PERSONAS ─────────────────────────────────────────────────────────
# 8 IAM users, 8 IAM roles, IAM groups, EKS access entries
# The FinTech RBAC scenario: Alice, Bob, Charlie, Dave, Eve, Frank, Grace, Henry
module "rbac_personas" {
  source = "./modules/rbac_personas"

  cluster_name = local.cluster_name
  cluster_arn  = module.eks.cluster_arn
  account_id   = data.aws_caller_identity.current.account_id
  tags         = local.common_tags
}

# ── S3 STATIC FRONTEND ────────────────────────────────────────────────────────
# Angular build deployed here manually via: aws s3 sync dist/ s3://<bucket>/
module "frontend_s3" {
  source = "./modules/frontend_s3"

  cluster_name = local.cluster_name
  environment  = var.environment
  tags         = local.common_tags
}
