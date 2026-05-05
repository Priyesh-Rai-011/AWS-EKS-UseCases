output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — used as reference; actual IRSA wiring is in the trust policy"
  value       = aws_iam_openid_connect_provider.eks.arn
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
  description = "IAM role ARN for ums-app pods — must be added to ServiceAccount annotation for IRSA"
  value       = aws_iam_role.ums_app_role.arn
}
