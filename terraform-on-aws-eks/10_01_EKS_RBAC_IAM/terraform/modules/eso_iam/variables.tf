variable "cluster_name" { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }
variable "secret_arns" { type = list(string) }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "tags" { type = map(string) }
