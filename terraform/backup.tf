resource "aws_backup_vault" "main" {
  name = "backup-vault-${var.prefix}"
  tags = local.common_tags
}

resource "aws_iam_role" "backup" {
  name = "backup-role-${var.prefix}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_plan" "main" {
  name = "backup-plan-${var.prefix}"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 * * ? *)"

    lifecycle {
      delete_after = 7
    }
  }
  tags = local.common_tags
}

resource "aws_backup_selection" "main" {
  name         = "backup-selection-${var.prefix}"
  plan_id      = aws_backup_plan.main.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [
    aws_db_instance.main.arn,
    aws_instance.vm.arn,
  ]
}

# Ransomware/tamper protection: once `changeable_for_days` elapses, this
# moves from governance mode into COMPLIANCE mode, where NO ONE —
# including the account root user and AWS Support — can shorten
# retention or delete the vault/backups until they expire. Use the
# 3-day grace window to verify everything still applies cleanly before
# it locks permanently; don't let this sit un-reviewed.
resource "aws_backup_vault_lock_configuration" "main" {
  backup_vault_name   = aws_backup_vault.main.name
  min_retention_days  = 7
  max_retention_days  = 30
  changeable_for_days = 3
}
