# =+=+=+=+=+=+=+=+=+=+=+=+=+=+

output "cluster_name" {
  value = aws_eks_cluster.basic_eks_cluster.name        # was: aws_eks_cluster.this
}

output "cluster_endpoint" {
  value = aws_eks_cluster.basic_eks_cluster.endpoint    # was: aws_eks_cluster.this
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.basic_eks_cluster.certificate_authority[0].data
}

output "privatelink_sg_id" {
  description = "SG attached to the PrivateLink ENI in your private subnet"
  value       = aws_security_group.private_link_sg.id   # was: privatelink_sg
}

output "node_role_arn" {
  value = aws_iam_role.eks_node_group_role.arn           # was: eks_node_role
}

output "node_group_status" {
  value = aws_eks_node_group.public_node_group.status   # was: private
}