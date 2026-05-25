# ==============================================================================
# SECRETS MANAGER — Shell Creation
# Creates empty secret containers in AWS Secrets Manager.
# Real values are seeded via CLI after terraform apply — never stored in state.
#
# prevent_destroy = true: terraform destroy will halt here.
# Cleanup sequence:
#   1. terraform destroy  → halts on these resources
#   2. aws secretsmanager delete-secret --secret-id <name> --force-delete-without-recovery
#   3. terraform state rm aws_secretsmanager_secret.<name>
#   4. terraform destroy  → now completes
# ==============================================================================

locals {
  prefix = "eks-secrets-${var.environment}"
}

resource "aws_secretsmanager_secret" "postgres" {
  name        = "${local.prefix}/pulseauth/postgres"
  description = "PulseAuth PostgreSQL credentials"

  tags = merge(var.common_tags, { Name = "${local.prefix}/pulseauth/postgres" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "redis" {
  name        = "${local.prefix}/pulseauth/redis"
  description = "PulseAuth Redis credentials"

  tags = merge(var.common_tags, { Name = "${local.prefix}/pulseauth/redis" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "mail" {
  name        = "${local.prefix}/pulseauth/mail"
  description = "PulseAuth SMTP mail credentials"

  tags = merge(var.common_tags, { Name = "${local.prefix}/pulseauth/mail" })

  lifecycle {
    prevent_destroy = true
  }
}
