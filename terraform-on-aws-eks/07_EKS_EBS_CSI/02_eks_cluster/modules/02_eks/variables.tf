variable "cluster_name"            { type = string }
variable "cluster_version"         { 
                                    type = string
                                    default = "1.33" 
                                    }

variable "vpc_id"                  { type = string }

variable "private_subnet_ids"      { type = list(string) }
variable "private_subnet_cidrs"    { type = list(string) }
variable "public_subnet_ids"       { type = list(string) }
variable "public_subnet_cidrs"     { type = list(string) }

# =======================================================================================
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "node_ami_type" {
  type    = string
  default = "AL2023_x86_64_STANDARD"
}
variable "node_disk_size" {
  type    = number
  default = 20
}
variable "node_desired_size" {
  type    = number
  default = 2
}
variable "node_min_size" {
  type    = number
  default = 2
}
variable "node_max_size" {
  type    = number
  default = 3
}
variable "addon_versions" {
  type    = map(string)
  default = {}
}
variable "enable_node_taint" {
  type    = bool
  default = true
}
# =======================================================================================

variable "endpoint_public_access" {
  type    = bool
  default = true
}
variable "endpoint_private_access" {
  type    = bool
  default = true
}
variable "enable_cluster_logging"  { 
    type = bool 
    default = false 
}
variable "tags"                    { 
    type = map(string)
    default = {} 
}
variable "bastion_role_arn"        { 
    type = string 
}