output "postgres_secret_arn" { value = aws_secretsmanager_secret.postgres.arn }
output "redis_secret_arn" { value = aws_secretsmanager_secret.redis.arn }
output "mail_secret_arn" { value = aws_secretsmanager_secret.mail.arn }

# eso_iam module needs this to scope the IAM policy to specific secret ARNs
output "secret_arns" {
  value = [
    aws_secretsmanager_secret.postgres.arn,
    aws_secretsmanager_secret.redis.arn,
    aws_secretsmanager_secret.mail.arn,
  ]
}

output "postgres_secret_name" { value = aws_secretsmanager_secret.postgres.name }
