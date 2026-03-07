# =+=+=+=+=+=+=+=+=+=+=+=+=+=+
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "private_subnet_ids" {
  description = "Private subnets for worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets for load balancers"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC where EKS will be deployed"
  type        = string
}

variable "node_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_nodes" {
  type    = number
  default = 2
}

variable "min_nodes" {
  type    = number
  default = 1
}

variable "max_nodes" {
  type    = number
  default = 3
}