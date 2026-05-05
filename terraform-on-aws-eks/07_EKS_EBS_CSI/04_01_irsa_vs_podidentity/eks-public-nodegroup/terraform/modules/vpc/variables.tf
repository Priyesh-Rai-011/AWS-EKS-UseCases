variable "name" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name — used for subnet discovery tags"
}

variable "vpc_cidr_block" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "database_subnets" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
