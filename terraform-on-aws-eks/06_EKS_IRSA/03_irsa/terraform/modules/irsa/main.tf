# ==============================================================================
# TRUST POLICY — WHO can assume this role
# Locked to: this specific cluster (via oidc_provider_arn)
#            + this specific namespace/serviceaccount (via sub condition)
# ==============================================================================
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Only the exact service account in the exact namespace can assume this role
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    # Only AWS STS can be the audience
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ==============================================================================
# IAM ROLE — the role the pod assumes via the projected token
# ==============================================================================
resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = merge(var.common_tags, { Name = var.role_name })
}

# ==============================================================================
# PERMISSIONS POLICY — WHAT this role can do
# s3:ListAllMyBuckets must use Resource = "*"
# AWS does not allow scoping ListAllMyBuckets to a specific bucket ARN
# ==============================================================================
resource "aws_iam_policy" "s3_list" {
  name        = "${var.role_name}-s3-list-policy"
  description = "Allows pod to list all buckets AND their contents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowListAllBucketNames"
        Effect   = "Allow"
        Action   = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowListingObjectsInsideBuckets"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        # Use "*" to allow listing contents of ALL buckets for this demo
        Resource = "*" 
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "s3_list" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.s3_list.arn
}