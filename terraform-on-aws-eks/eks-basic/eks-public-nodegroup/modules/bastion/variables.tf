# =+=+=+=+=+=+=+=+=+=+=+=+=+=+
variable "name" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

# comes FROM vpc module output
variable "vpc_id" {
  type = string
}

# comes FROM vpc module output - public subnet
variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "root_volume_type" {
  type    = string
  default = "gp3"
}

variable "root_volume_delete_on_termination" {
  type    = bool
  default = true
}

variable "root_volume_encrypted" {
  type    = bool
  default = true
}