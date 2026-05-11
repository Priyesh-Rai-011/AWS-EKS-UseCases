variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
