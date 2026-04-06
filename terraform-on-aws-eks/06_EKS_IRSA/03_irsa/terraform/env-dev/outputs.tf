# this iam_role_arn is to be taken and copied into k8s-manifests/service-account.yaml -------------------
output "iam_role_arn" {
  description = "Paste into service-account.yaml annotation: eks.amazonaws.com/role-arn"
  value       = module.irsa.iam_role_arn
}