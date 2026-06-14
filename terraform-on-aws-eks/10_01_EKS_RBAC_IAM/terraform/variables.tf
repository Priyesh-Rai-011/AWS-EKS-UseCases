variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "eks-public"
}

# State key for existing cluster (from module 07 or 09)
variable "cluster_state_bucket" {
  description = "S3 bucket holding existing cluster remote state"
  type        = string
  default     = "learning-remotebackend2"
}

variable "cluster_state_key" {
  description = "State key for existing EKS cluster"
  type        = string
  default     = "terraform-on-aws-eks/09_EKS_Secrets_Management/terraform.tfstate"
}
