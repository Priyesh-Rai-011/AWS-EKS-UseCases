variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ── VPC ───────────────────────────────────────────────────────────────────────
variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "database_subnets" {
  type    = list(string)
  default = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

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
  description = "Enable EKS audit logs → CloudWatch (set true to enable audit trail)"
  type        = bool
  default     = true
}

# ── BASTION ───────────────────────────────────────────────────────────────────
variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

# ── ECR ───────────────────────────────────────────────────────────────────────
variable "ecr_repository_name" {
  description = "ECR repo for PulseAuth backend image"
  type        = string
  default     = "pulseauth"
}
