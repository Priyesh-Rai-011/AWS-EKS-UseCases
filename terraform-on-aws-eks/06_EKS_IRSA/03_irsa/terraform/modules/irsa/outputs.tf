output "iam_role_arn" {
  description = "Paste this into k8s-manifests/service-account.yaml annotation"
  value       = aws_iam_role.this.arn
}

output "iam_role_name" {
  value = aws_iam_role.this.name
}