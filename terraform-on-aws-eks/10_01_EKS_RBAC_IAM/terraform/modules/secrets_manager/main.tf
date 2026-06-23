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

resource "aws_secretsmanager_secret" "postgres" {
  name                    = "${var.cluster_name}/pulseauth/postgres"
  description             = "PulseAuth PostgreSQL credentials — seed via CLI after apply"
  recovery_window_in_days = 0 # immediate delete ok in dev — set 7 for prod

  tags = merge(var.common_tags, { Name = "${var.cluster_name}/pulseauth/postgres" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id     = aws_secretsmanager_secret.postgres.id
  secret_string = jsonencode({})
}

resource "aws_secretsmanager_secret" "redis" {
  name                    = "${var.cluster_name}/pulseauth/redis"
  description             = "PulseAuth Redis credentials — seed via CLI after apply"
  recovery_window_in_days = 0

  tags = merge(var.common_tags, { Name = "${var.cluster_name}/pulseauth/redis" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id     = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({})
}

resource "aws_secretsmanager_secret" "mail" {
  name                    = "${var.cluster_name}/pulseauth/mail"
  description             = "PulseAuth SMTP mail credentials — seed via CLI after apply"
  recovery_window_in_days = 0

  tags = merge(var.common_tags, { Name = "${var.cluster_name}/pulseauth/mail" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "mail" {
  secret_id     = aws_secretsmanager_secret.mail.id
  secret_string = jsonencode({})
}
