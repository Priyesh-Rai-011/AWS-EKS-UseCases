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
