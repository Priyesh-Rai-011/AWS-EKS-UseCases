resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name        = each.value.name
  description = each.value.description

  # 0 in dev/test allows immediate re-creation without waiting 30 days
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, { Name = each.value.name })
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.secrets

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = each.value.secret_string
}
