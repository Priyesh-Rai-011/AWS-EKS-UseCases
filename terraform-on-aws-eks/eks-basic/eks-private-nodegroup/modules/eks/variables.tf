# =+=+=+=+=+=+=+=+=+=+=+=+=+=+

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

variable "private_subnet_ids" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Used in the PrivateLink SG ingress rule to allow port 443 from nodes"
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

variable "tags" {
  type    = map(string)
  default = {}
}