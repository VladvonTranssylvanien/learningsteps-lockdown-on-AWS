# Stores the RDS password so it never needs to live in plaintext on the
# VM's user_data or in a locally-committed file. Mirrors the Key Vault +
# Managed Identity pattern from the Azure original.
resource "aws_secretsmanager_secret" "db_password" {
  name        = "rds-password-${var.prefix}"
  description = "PostgreSQL admin password for LearningSteps RDS instance"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_admin_password
}

# Grants the VM's IAM role permission to read only this one secret,
# not all secrets in the account (least privilege).
resource "aws_iam_role_policy" "vm_read_db_secret" {
  name = "read-db-secret"
  role = aws_iam_role.vm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}

resource "aws_secretsmanager_secret" "crowdsec_bouncer_key" {
  name        = "crowdsec-bouncer-key-${var.prefix}"
  description = "CrowdSec bouncer API key for NPMplus WAF integration"

  tags = local.common_tags
}

resource "aws_iam_role_policy" "vm_read_crowdsec_secret" {
  name = "read-crowdsec-secret"
  role = aws_iam_role.vm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.crowdsec_bouncer_key.arn
      }
    ]
  })
}
