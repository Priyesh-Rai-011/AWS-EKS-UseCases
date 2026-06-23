data "aws_caller_identity" "current" {}

# IRSA role for pulseauth-sa in backend-prod namespace
# ESO SecretStore uses this SA to authenticate to AWS Secrets Manager
resource "aws_iam_role" "eso_role" {
  name        = "${var.cluster_name}-pulseauth-eso-role"
  description = "Assumed by pulseauth-sa via IRSA to read secrets from AWS Secrets Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:backend-prod:pulseauth-sa"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-pulseauth-eso-role" })
}

resource "aws_iam_role_policy" "eso_secrets_policy" {
  name = "pulseauth-eso-secrets-policy"
  role = aws_iam_role.eso_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      Resource = var.secret_arns
    }]
  })
}
