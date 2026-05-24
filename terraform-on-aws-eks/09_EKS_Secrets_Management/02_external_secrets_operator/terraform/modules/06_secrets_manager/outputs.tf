output "postgres_secret_arn" {
  value = aws_secretsmanager_secret.postgres.arn
}

output "redis_secret_arn" {
  value = aws_secretsmanager_secret.redis.arn
}

output "mail_secret_arn" {
  value = aws_secretsmanager_secret.mail.arn
}
