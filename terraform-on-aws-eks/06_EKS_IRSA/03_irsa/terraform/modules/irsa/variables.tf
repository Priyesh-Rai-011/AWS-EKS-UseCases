variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the OIDC provider — output from 02_eks_cluster"
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC issuer URL without https:// — output from 02_eks_cluster"
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role the pod will assume"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where the service account lives"
}

variable "service_account_name" {
  type        = string
  description = "Kubernetes service account name bound to this role"
}

variable "common_tags" {
  type        = map(string)
  default     = {}
}