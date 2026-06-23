output "role_arns" {
  value = {
    cluster_admin     = aws_iam_role.roles["cluster_admin"].arn
    devops_admin      = aws_iam_role.roles["devops_admin"].arn
    devops            = aws_iam_role.roles["devops"].arn
    backend_dev_admin = aws_iam_role.roles["backend_dev_admin"].arn
    backend_dev       = aws_iam_role.roles["backend_dev"].arn
    frontend_dev      = aws_iam_role.roles["frontend_dev"].arn
    readonly          = aws_iam_role.roles["readonly"].arn
    security          = aws_iam_role.roles["security"].arn
  }
}
