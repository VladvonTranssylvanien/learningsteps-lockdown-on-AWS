resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts-${var.prefix}"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.prefix}"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_iam_role" "cloudtrail_to_cloudwatch" {
  name = "cloudtrail-to-cloudwatch-${var.prefix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cloudtrail_to_cloudwatch" {
  name = "write-logs"
  role = aws_iam_role.cloudtrail_to_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  name           = "root-account-usage-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_usage" {
  alarm_name          = "root-account-usage-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts when the AWS root account is used for any action"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "iam_changes" {
  name           = "iam-changes-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventSource = \"iam.amazonaws.com\") && (($.eventName = \"Delete*\") || ($.eventName = \"Put*\") || ($.eventName = \"Create*\") || ($.eventName = \"Attach*\") || ($.eventName = \"Detach*\")) }"

  metric_transformation {
    name      = "IAMChanges"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_changes" {
  alarm_name          = "iam-changes-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "IAMChanges"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts when an IAM user, role, or policy is created, modified, or deleted"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}
