resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "analyzer-${var.prefix}"
  type          = "ACCOUNT"

  tags = local.common_tags
}
