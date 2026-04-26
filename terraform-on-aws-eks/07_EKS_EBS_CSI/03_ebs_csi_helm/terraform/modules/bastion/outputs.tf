output "bastion_role_arn" {
  description = "IAM role ARN attached to the bastion EC2 instance"
  value       = aws_iam_role.bastion_ssm_role.arn
}

output "bastion_instance_id" {
  description = "EC2 instance ID - use with SSM start-session"
  value       = aws_instance.bastion.id
}

output "bastion_security_group_id" {
  description = "SG ID of the bastion host"
  value       = aws_security_group.bastion_sg.id
}

output "ssm_connect_command" {
  description = "Run this command to connect to the bastion via SSM"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.aws_region}"
}

output "bastion_private_ip" {
  description = "Private IP of the bastion - connect via SSM, not SSH"
  value       = aws_instance.bastion.private_ip
}
