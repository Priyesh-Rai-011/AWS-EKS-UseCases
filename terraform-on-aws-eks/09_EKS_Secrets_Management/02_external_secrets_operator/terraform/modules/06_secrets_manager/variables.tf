variable "environment" {
  description = "Deployment environment (dev/staging/prod) — used to build secret path eks-secrets-<env>/pulseauth/*"
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
