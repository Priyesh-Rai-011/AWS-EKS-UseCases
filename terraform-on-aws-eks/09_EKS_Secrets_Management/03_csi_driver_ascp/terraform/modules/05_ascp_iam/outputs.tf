output "ascp_role_arn" {
  description = "IAM role ARN for ASCP — annotate the ${var.namespace}/${var.service_account_name} service account with this value"
  value       = aws_iam_role.ascp_role.arn
}
