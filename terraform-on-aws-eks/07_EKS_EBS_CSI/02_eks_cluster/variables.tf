# =+=+=+=+=+=+=+=+=+=+=+=+=+=+

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

# ── VPC ───────────────────────────────────────────────────────────────────────
variable "vpc_cidr_block" {
  type    = string
  default = "10.1.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
}

variable "database_subnets" {
  type    = list(string)
  default = ["10.1.21.0/24", "10.1.22.0/24", "10.1.23.0/24"]
}
# # ── VPC ───────────────────────────────────────────────────────────────────────
# variable "vpc_cidr_block" {
#   type    = string
#   default = "10.0.0.0/16"
# }

# variable "public_subnets" {
#   type    = list(string)
#   default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
# }

# variable "private_subnets" {
#   type    = list(string)
#   default = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
# }

# variable "database_subnets" {
#   type    = list(string)
#   default = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
# }

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

# ── EKS ───────────────────────────────────────────────────────────────────────
variable "cluster_version" {
  type    = string
  default = "1.33"
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

# ── BASTION ───────────────────────────────────────────────────────────────────
variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}