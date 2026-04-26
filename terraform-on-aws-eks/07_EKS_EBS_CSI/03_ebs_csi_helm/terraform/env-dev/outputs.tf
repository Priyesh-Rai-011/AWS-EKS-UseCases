output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ebs_csi_role_arn" {
  description = "IRSA IAM role ARN used by EBS CSI driver"
  value       = module.ebs_csi.ebs_csi_role_arn
}

output "helm_release_status" {
  description = "Helm release deployment status"
  value       = module.ebs_csi.helm_release_status
}

output "configure_kubectl" {
  description = "Run after terraform apply to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "bastion_instance_id" {
  value = module.bastion.bastion_instance_id
}

output "ssm_connect_command" {
  description = "Connect to bastion via SSM Session Manager"
  value       = module.bastion.ssm_connect_command
}
