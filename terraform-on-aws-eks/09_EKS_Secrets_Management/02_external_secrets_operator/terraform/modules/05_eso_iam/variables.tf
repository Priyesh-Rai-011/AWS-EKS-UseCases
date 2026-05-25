variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider — used in the trust policy Principal"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL without https:// — used as condition key in trust policy"
  type        = string
}

variable "aws_region" {
  description = "AWS region — used to scope Secrets Manager resource ARN"
  type        = string
  default     = "ap-south-1"
}

variable "secret_arns" {
  description = "Exact ARNs of Secrets Manager secrets ESO is allowed to read — from module.secrets_manager outputs"
  type        = list(string)
}

variable "environment" {
  description = "Deployment environment (dev/staging/prod) — used to scope SSM parameter path"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
