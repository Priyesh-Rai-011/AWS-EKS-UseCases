output "role_arns" {
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
