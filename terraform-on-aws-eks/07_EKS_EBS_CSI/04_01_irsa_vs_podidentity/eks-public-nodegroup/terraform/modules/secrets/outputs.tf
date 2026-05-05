output "secret_arns" {
  description = "Map of logical key -> secret ARN"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}

output "secret_names" {
  description = "Map of logical key -> secret name in Secrets Manager"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.name }
}
