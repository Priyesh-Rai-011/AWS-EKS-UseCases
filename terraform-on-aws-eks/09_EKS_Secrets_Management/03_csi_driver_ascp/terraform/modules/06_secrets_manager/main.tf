# ==============================================================================
# SECRETS MANAGER — Shell Creation
# Creates single consolidated secret for CSI/ASCP variant.
# Real values are seeded via CLI after terraform apply — never stored in state.
#
# prevent_destroy = true: terraform destroy will halt here.
# Cleanup sequence:
#   1. terraform destroy  → halts on this resource
#   2. aws secretsmanager delete-secret --secret-id <name> --force-delete-without-recovery
#   3. terraform state rm aws_secretsmanager_secret.pulseauth_all
#   4. terraform destroy  → now completes
# ==============================================================================

locals {
  prefix = "eks-secrets-${var.environment}"
}

resource "aws_secretsmanager_secret" "pulseauth_all" {
  name        = "${local.prefix}/pulseauth/all"
  description = "PulseAuth all credentials (DB, Redis, Mail) — consumed via ASCP CSI driver"

  tags = merge(var.common_tags, { Name = "${local.prefix}/pulseauth/all" })

  lifecycle {
    prevent_destroy = true
  }
}
