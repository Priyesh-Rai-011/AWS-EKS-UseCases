output "repository_url" {
  description = "Full ECR repository URL — use this as the image field in your pod spec"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.this.arn
}
