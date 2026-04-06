output "cluster_name" {
  value = aws_eks_cluster.basic_eks_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.basic_eks_cluster.endpoint
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.basic_eks_cluster.certificate_authority[0].data
}

output "privatelink_sg_id" {
  value = aws_security_group.private_link_sg.id
}

output "node_role_arn" {
  value = aws_iam_role.eks_node_group_role.arn
}

output "node_group_status" {
  value = aws_eks_node_group.public_node_group.status
}

# -- OIDC — needed by 03_irsa ------------------------------------------
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider — goes into irsa trust policy"
  value       = aws_iam_openid_connect_provider.oidc_provider.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without https:// — used as condition key in trust policy"
  value       = trimprefix(aws_eks_cluster.basic_eks_cluster.identity[0].oidc[0].issuer, "https://")
}