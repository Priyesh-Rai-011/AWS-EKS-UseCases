variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider — used in the trust policy Principal"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL without https:// — used as condition key in trust policy"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name that the ASCP workload pod will use"
  type        = string
  default     = "pulseauth"
}

variable "namespace" {
  description = "Kubernetes namespace where the ASCP workload runs"
  type        = string
  default     = "pulseauth"
}

variable "tags" {
  type    = map(string)
  default = {}
}
