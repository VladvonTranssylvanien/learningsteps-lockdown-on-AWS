resource "aws_kms_key" "rds" {
  description             = "Customer-managed key for RDS encryption - learningsteps"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.common_tags
}

resource "aws_kms_alias" "rds" {
  name          = "alias/rds-${var.prefix}"
  target_key_id = aws_kms_key.rds.key_id
}
