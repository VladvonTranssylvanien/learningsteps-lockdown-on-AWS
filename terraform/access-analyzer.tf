resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "analyzer-${var.prefix}"
  type          = "ACCOUNT"

  tags = local.common_tags
}

# Flags roles/users with permissions they haven't actually used in
# 90 days, separate from the external-access analyzer above.
resource "aws_accessanalyzer_analyzer" "unused_access" {
  analyzer_name = "unused-access-analyzer-${var.prefix}"
  type          = "ACCOUNT_UNUSED_ACCESS"

  configuration {
    unused_access {
      unused_access_age = 90
    }
  }

  tags = local.common_tags
}
