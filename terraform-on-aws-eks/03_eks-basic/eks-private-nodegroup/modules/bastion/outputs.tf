# =+=+=+=+=+=+=+=+=+=+=+=+=+=+
output "bastion_role_arn" {
  description = "IAM role ARN attached to the bastion EC2 instance"
  value       = aws_iam_role.bastion_ssm_role.arn
}

output "bastion_instance_id" {
  description = "EC2 instance ID — use this to start SSM session"
  value       = aws_instance.bastion.id
}

output "bastion_security_group_id" {
  description = "Use this SG ID in private instance rules to allow traffic from bastion only"
  value       = aws_security_group.bastion_sg.id
}

output "ssm_connect_command" {
  description = "Run this command in your terminal to connect via SSM"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.aws_region}"
}

output "bastion_private_ip" {
  description = "Private IP of the bastion — connect via SSM, not SSH"
  value       = aws_instance.bastion.private_ip
}