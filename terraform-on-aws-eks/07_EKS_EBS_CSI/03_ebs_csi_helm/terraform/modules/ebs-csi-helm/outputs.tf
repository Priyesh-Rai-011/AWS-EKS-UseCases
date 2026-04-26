output "ebs_csi_role_arn" {
  description = "IRSA IAM role ARN used by EBS CSI controller ServiceAccount"
  value       = aws_iam_role.ebs_csi_driver_role.arn
}
