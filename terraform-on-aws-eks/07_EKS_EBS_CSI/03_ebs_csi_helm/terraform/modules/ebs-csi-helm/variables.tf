variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster to install EBS CSI driver on"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
