output "cluster_name" {
  description = "EKS cluster name (from remote state)"
  value       = local.cluster_name
}

output "iam_role_arns" {
  description = "All IAM role ARNs created for RBAC testing"
  value = {
    cluster_admin    = aws_iam_role.cluster_admin.arn
    devops_admin     = aws_iam_role.devops_admin.arn
    devops           = aws_iam_role.devops.arn
    backend_dev_admin = aws_iam_role.backend_dev_admin.arn
    backend_dev      = aws_iam_role.backend_dev.arn
    frontend_dev     = aws_iam_role.frontend_dev.arn
    readonly         = aws_iam_role.readonly.arn
    security         = aws_iam_role.security.arn
  }
}

output "assume_role_commands" {
  description = "STS assume-role commands for each persona"
  value = {
    alice   = "aws sts assume-role --role-arn ${aws_iam_role.devops_admin.arn} --role-session-name alice"
    bob     = "aws sts assume-role --role-arn ${aws_iam_role.devops.arn} --role-session-name bob"
    charlie = "aws sts assume-role --role-arn ${aws_iam_role.backend_dev_admin.arn} --role-session-name charlie"
    dave    = "aws sts assume-role --role-arn ${aws_iam_role.backend_dev.arn} --role-session-name dave"
    eve     = "aws sts assume-role --role-arn ${aws_iam_role.frontend_dev.arn} --role-session-name eve"
    frank   = "aws sts assume-role --role-arn ${aws_iam_role.devops.arn} --role-session-name frank"
    grace   = "aws sts assume-role --role-arn ${aws_iam_role.security.arn} --role-session-name grace"
  }
}
