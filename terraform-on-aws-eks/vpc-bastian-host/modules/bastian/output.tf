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
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ap-south-1"
}