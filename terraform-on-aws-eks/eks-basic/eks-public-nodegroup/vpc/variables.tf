# =+=+=+=+=+=+=+=+=+=+=+=+=+=+
variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type        = string
  
}

variable "name" {
    description = "Name prefix for all resources"
    type        = string
}
variable "common_tags" {
  type    = map(string)
  default = {}
}
# internet gateway 
variable "enable_nat_gateway" {
    description = "Whether to create a NAT Gateway for private subnets"
    type        = bool
    default     = true
}
variable "single_nat_gateway" {
    description = "Whether to create a single NAT Gateway for all private subnets"
    type = bool
    default = false
}


# subnets
variable "public_subnets" {
    description = "List of CIDR blocks for public subnets"
    type        = list(string)
    default = []
}
variable "map_public_ip_on_launch" {
    description = "Whether to map public IP on launch for public subnets"
    type        = bool
    default     = true
}

variable "private_subnets" {
    description = "List of CIDR blocks for the private subnets"
    type        = list(string)
    default = []
}
variable "database_subnets" {
    description = "List of CIDR blocks for the database subnets"
    type        = list(string)
    default = []
}