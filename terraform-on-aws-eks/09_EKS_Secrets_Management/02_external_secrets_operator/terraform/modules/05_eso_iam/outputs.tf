output "eso_role_arn" {
  description = "IAM role ARN for ESO — annotate the external-secrets service account with this value"
  value       = aws_iam_role.eso_role.arn
}
