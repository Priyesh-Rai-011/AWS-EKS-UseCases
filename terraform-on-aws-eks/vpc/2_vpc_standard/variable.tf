variable "vpc_name" {
    description = "The name of the VPC"
    type        = string
    default     = "basic-vpc"
}
variable "vpc_cidr_block" {
    description = "The CIDR block for the VPC"
    type        = string
    default     = "10.0.0.0/16"
}


variable "availability_zones" {
  default = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "public_subnets" {
    description = "List of CIDR blocks for public subnets"
    type        = list(string)
    default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "private_subnets" {
    description = "List of CIDR blocks for private subnets"
    type        = list(string)
    default     = ["10.0.11.0/24", "10.0.12.0/24","10.0.13.0/24"]           
}
variable "database_subnets" {
    description = "List of CIDR blocks for database subnets"
    type        = list(string)
    default     = ["10.0.21.0/24", "10.0.22.0/24","10.0.23.0/24"]           
}

variable "vpc_enable_nat_gateway" {
  description = "Whether to enable NAT gateway for private subnets"
  type        = bool
  default     = true
}

variable "vpc_single_nat_gateway" {
  description = "Whether to use a single NAT gateway for all private subnets"
  type        = bool
  default     = false
}