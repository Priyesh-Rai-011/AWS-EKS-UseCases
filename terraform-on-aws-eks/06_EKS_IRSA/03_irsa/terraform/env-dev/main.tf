data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "learning-remotebackend2"
    key    = "terraform-on-aws-eks/eks-private-nodegroup/terraform.tfstate"
    region = "ap-south-1"
  }
}

module "irsa" {
  source = "../modules/irsa"

  # oidc_provider_arn    = var.oidc_provider_arn
  oidc_provider_arn    = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  # oidc_provider_url    = var.oidc_provider_url
  oidc_provider_url    = data.terraform_remote_state.eks.outputs.oidc_provider_url

  role_name            = "${local.name}-s3-list-role"
  namespace            = var.namespace
  service_account_name = var.service_account_name

  common_tags          = local.common_tags
}


# this is to be 
# 