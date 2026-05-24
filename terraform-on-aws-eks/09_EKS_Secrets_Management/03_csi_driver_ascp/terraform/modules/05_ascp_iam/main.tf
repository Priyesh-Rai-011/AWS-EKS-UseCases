data "aws_caller_identity" "current" {}

# ==============================================================================
# ASCP IAM ROLE — AWS Secrets & Configuration Provider (CSI Driver)
# Assumed by: the application pod via IRSA
# Service account: var.service_account_name / namespace: var.namespace
#
# IRSA flow:
#   1. Pod gets a projected service account token (OIDC JWT)
#   2. ASCP (mounted as CSI volume) exchanges token with STS using AssumeRoleWithWebIdentity
#   3. STS checks the Condition block — sa name + namespace + audience must match
#   4. Pod gets temporary credentials scoped to this role only
#   5. ASCP uses those credentials to fetch the secret and mount it as a file
# ==============================================================================
resource "aws_iam_role" "ascp_role" {
  name        = "${var.namespace}-ascp-role"
  description = "Assumed by ${var.namespace}/${var.service_account_name} pod via IRSA to read secrets via ASCP"

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
          # Only the specific service account in the specific namespace can assume this role
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, { Name = "${var.namespace}-ascp-role" })
}

# ── Inline policy — Secrets Manager + SSM Parameter Store read access ─────────
resource "aws_iam_role_policy" "ascp_secrets_policy" {
  name = "${var.namespace}-ascp-secrets-policy"
  role = aws_iam_role.ascp_role.name

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
        Resource = var.secret_arns
      },
      {
        Sid    = "SSMParameterStoreRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",            # Fetch a single parameter by exact name
          "ssm:GetParameters",           # Fetch multiple parameters by name list
          "ssm:GetParametersByPath",     # Fetch all parameters under a path prefix (e.g. /app/prod/)
        ]
        # Scoped to the pulseauth path — wildcards match /eks-secrets-dev/pulseauth/<name>
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/eks-secrets-${var.environment}/pulseauth/*"
      }
    ]
  })
}
