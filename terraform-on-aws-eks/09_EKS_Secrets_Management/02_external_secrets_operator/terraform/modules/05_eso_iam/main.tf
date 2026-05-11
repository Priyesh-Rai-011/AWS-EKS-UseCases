# ==============================================================================
# ESO IAM ROLE — External Secrets Operator
# Assumed by: the ESO controller pod via IRSA
# Service account: external-secrets / namespace: external-secrets
#
# IRSA flow:
#   1. Pod gets a projected service account token (OIDC JWT)
#   2. ESO exchanges that token with STS using AssumeRoleWithWebIdentity
#   3. STS checks the Condition block — sa name + audience must match exactly
#   4. Pod receives temporary AWS credentials scoped to this role only
# ==============================================================================
resource "aws_iam_role" "eso_role" {
  name        = "external-secrets-operator-role"
  description = "Assumed by External Secrets Operator via IRSA to read secrets from AWS"

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
          # Only the ESO controller service account in the external-secrets namespace can assume this role
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, { Name = "external-secrets-operator-role" })
}

# ── Inline policy — Secrets Manager + SSM Parameter Store read access ─────────
resource "aws_iam_role_policy" "eso_secrets_policy" {
  name = "eso-secrets-read-policy"
  role = aws_iam_role.eso_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",  # Fetch the secret payload
          "secretsmanager:DescribeSecret",  # Read metadata (rotation status, ARN, etc.)
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMParameterStoreRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",    # Fetch a single parameter by name
          "ssm:GetParameters",   # Fetch multiple parameters by name list
        ]
        Resource = "*"
      }
    ]
  })
}
