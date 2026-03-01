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