variable "name" {
  type = string
}
variable "common_tags" {
  type    = map(string)
  default = {}
}
variable "vpc_id" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "aws_region" {
  type = string
}
variable "cluster_name" {
  type = string
}
output "bastion_role_arn" {
  description = "IAM role ARN attached to the bastion EC2 instance"
  value       = aws_iam_role.bastion_ssm_role.arn
}