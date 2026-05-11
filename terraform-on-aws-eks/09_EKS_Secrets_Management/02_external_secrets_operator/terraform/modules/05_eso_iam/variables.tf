variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider — used in the trust policy Principal"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL without https:// — used as condition key in trust policy"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
