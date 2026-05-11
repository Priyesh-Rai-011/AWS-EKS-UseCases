output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "privatelink_sg_id" {
  description = "SG attached to the PrivateLink ENI in the VPC"
  value       = aws_security_group.private_link_sg.id
}

output "node_role_arn" {
  value = aws_iam_role.eks_node_group_role.arn
}

output "node_group_status" {
  value = aws_eks_node_group.node_group.status
}

output "ums_app_role_arn" {
  description = "IAM role ARN for ums-app pods — assumed via IRSA to access Secrets Manager"
  value       = aws_iam_role.ums_app_role.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider — used for IRSA trust policies"
  value       = aws_iam_openid_connect_provider.eks.arn
}
