variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "Private subnet ID - bastion accessed via SSM, not public IP"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
