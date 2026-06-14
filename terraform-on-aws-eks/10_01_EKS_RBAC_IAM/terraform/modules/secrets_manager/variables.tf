variable "cluster_name" {
  description = "Cluster name used as secret path prefix: <cluster_name>/pulseauth/*"
  type        = string
}

variable "environment" {
  type = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
