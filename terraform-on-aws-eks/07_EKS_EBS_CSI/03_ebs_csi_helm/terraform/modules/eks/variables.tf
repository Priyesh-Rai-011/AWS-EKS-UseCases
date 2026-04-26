variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs - allowed to reach EKS API server on 443"
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs - allowed to reach EKS API server on 443"
}

variable "endpoint_public_access" {
  type    = bool
  default = true
}

variable "endpoint_private_access" {
  type    = bool
  default = true
}

variable "enable_cluster_logging" {
  type    = bool
  default = false
}

variable "bastion_role_arn" {
  type        = string
  description = "IAM role ARN of the bastion host - granted EKS cluster admin access"
}

variable "tags" {
  type    = map(string)
  default = {}
}
