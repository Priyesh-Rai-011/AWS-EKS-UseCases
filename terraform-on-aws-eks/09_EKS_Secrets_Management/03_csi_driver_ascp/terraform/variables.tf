# =+=+=+=+=+=+=+=+=+=+=+=+=+=+

variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod) — used in resource names and tags"
  type        = string
  default     = "dev"
}

# ── VPC ───────────────────────────────────────────────────────────────────────
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets — one per AZ, hosts NAT GW and LBs"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets — one per AZ, hosts EKS nodes"
  type        = list(string)
  default     = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
}

variable "database_subnets" {
  description = "CIDR blocks for database subnets — isolated, no internet route"
  type        = list(string)
  default     = ["10.1.21.0/24", "10.1.22.0/24", "10.1.23.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnet outbound traffic"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway across all AZs (cheaper for dev, not HA)"
  type        = bool
  default     = true
}

# ── EKS ───────────────────────────────────────────────────────────────────────
variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "endpoint_public_access" {
  description = "Enable public API endpoint — required when accessing cluster from outside VPC"
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Enable private API endpoint — nodes use this to reach the control plane without leaving VPC"
  type        = bool
  default     = true
}

variable "enable_cluster_logging" {
  description = "Send EKS control plane logs (api, audit, authenticator, etc.) to CloudWatch"
  type        = bool
  default     = false
}

# ── BASTION ───────────────────────────────────────────────────────────────────
variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

# ── ECR ───────────────────────────────────────────────────────────────────────
variable "ecr_repository_name" {
  description = "Name of the ECR repository to create for PulseAuth container images"
  type        = string
  default     = "pulseauth"
}

# ── ASCP ──────────────────────────────────────────────────────────────────────
variable "ascp_service_account_name" {
  description = "Kubernetes service account name that ASCP pod will use"
  type        = string
  default     = "pulseauth"
}

variable "ascp_namespace" {
  description = "Kubernetes namespace where the ASCP workload runs"
  type        = string
  default     = "pulseauth"
}
