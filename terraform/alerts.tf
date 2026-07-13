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

resource "aws_cloudwatch_log_metric_filter" "console_login_failures" {
  name           = "console-login-failures-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = \"ConsoleLogin\") && ($.responseElements.ConsoleLogin = \"Failure\") }"

  metric_transformation {
    name      = "ConsoleLoginFailures"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "console_login_failures" {
  alarm_name          = "console-login-failures-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ConsoleLoginFailures"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts when a console login failure is recorded"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "unauthorized-api-calls-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ $.errorCode = \"UnauthorizedOperation\" }"

  metric_transformation {
    name      = "UnauthorizedApiCalls"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "unauthorized-api-calls-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedApiCalls"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts when an unauthorized AWS API call is detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

# CIS 3.5: catches an attacker (or mistake) disabling/altering the trail
# itself, which would otherwise blind every other alarm in this file.
resource "aws_cloudwatch_log_metric_filter" "access_key_changes" {
  name           = "access-key-changes-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventSource = \"iam.amazonaws.com\") && (($.eventName = \"CreateAccessKey\") || ($.eventName = \"DeleteAccessKey\") || ($.eventName = \"UpdateAccessKey\")) }"

  metric_transformation {
    name      = "AccessKeyChanges"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "access_key_changes" {
  alarm_name          = "access-key-changes-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "AccessKeyChanges"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts when IAM access keys are created, updated, or deleted"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "cloudtrail_changes" {
  name           = "cloudtrail-changes-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = \"CreateTrail\") || ($.eventName = \"UpdateTrail\") || ($.eventName = \"DeleteTrail\") || ($.eventName = \"StartLogging\") || ($.eventName = \"StopLogging\") }"

  metric_transformation {
    name      = "CloudTrailChanges"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudtrail_changes" {
  alarm_name          = "cloudtrail-changes-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CloudTrailChanges"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts when CloudTrail configuration is created, updated, deleted, or logging is stopped"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

# CIS 3.2: a successful console login that did NOT use MFA.
resource "aws_cloudwatch_log_metric_filter" "console_login_no_mfa" {
  name           = "console-login-no-mfa-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.userIdentity.type = \"IAMUser\") && ($.responseElements.ConsoleLogin = \"Success\") }"

  metric_transformation {
    name      = "ConsoleLoginNoMFA"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "console_login_no_mfa" {
  alarm_name          = "console-login-no-mfa-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ConsoleLoginNoMFA"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts on a successful console login without MFA"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

# CIS 3.7: a disabled or scheduled-for-deletion CMK would break RDS/EC2
# volume decryption and the CloudTrail log encryption above.
resource "aws_cloudwatch_log_metric_filter" "kms_key_changes" {
  name           = "kms-key-changes-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventSource = \"kms.amazonaws.com\") && (($.eventName = \"DisableKey\") || ($.eventName = \"ScheduleKeyDeletion\")) }"

  metric_transformation {
    name      = "KMSKeyChanges"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "kms_key_changes" {
  alarm_name          = "kms-key-changes-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "KMSKeyChanges"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts when a customer-managed KMS key is disabled or scheduled for deletion"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

# CIS 3.10: security group rule/create/delete changes.
resource "aws_cloudwatch_log_metric_filter" "security_group_changes" {
  name           = "security-group-changes-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = \"AuthorizeSecurityGroupIngress\") || ($.eventName = \"AuthorizeSecurityGroupEgress\") || ($.eventName = \"RevokeSecurityGroupIngress\") || ($.eventName = \"RevokeSecurityGroupEgress\") || ($.eventName = \"CreateSecurityGroup\") || ($.eventName = \"DeleteSecurityGroup\") }"

  metric_transformation {
    name      = "SecurityGroupChanges"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  alarm_name          = "security-group-changes-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityGroupChanges"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts when a security group is created, deleted, or its rules change"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

# CIS 3.11-3.14 combined into one filter/alarm to stay within the
# always-free 10-alarm CloudWatch budget: NACL, gateway, route table,
# and VPC-level changes.
resource "aws_cloudwatch_log_metric_filter" "network_changes" {
  name           = "network-changes-${var.prefix}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ ($.eventName = \"CreateNetworkAcl\") || ($.eventName = \"CreateNetworkAclEntry\") || ($.eventName = \"DeleteNetworkAcl\") || ($.eventName = \"DeleteNetworkAclEntry\") || ($.eventName = \"ReplaceNetworkAclEntry\") || ($.eventName = \"ReplaceNetworkAclAssociation\") || ($.eventName = \"CreateCustomerGateway\") || ($.eventName = \"DeleteCustomerGateway\") || ($.eventName = \"AttachInternetGateway\") || ($.eventName = \"CreateInternetGateway\") || ($.eventName = \"DeleteInternetGateway\") || ($.eventName = \"DetachInternetGateway\") || ($.eventName = \"CreateRoute\") || ($.eventName = \"CreateRouteTable\") || ($.eventName = \"ReplaceRoute\") || ($.eventName = \"ReplaceRouteTableAssociation\") || ($.eventName = \"DeleteRouteTable\") || ($.eventName = \"DeleteRoute\") || ($.eventName = \"DisassociateRouteTable\") || ($.eventName = \"CreateVpc\") || ($.eventName = \"DeleteVpc\") || ($.eventName = \"ModifyVpcAttribute\") }"

  metric_transformation {
    name      = "NetworkChanges"
    namespace = "CloudTrailMetrics-${var.prefix}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "network_changes" {
  alarm_name          = "network-changes-${var.prefix}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "NetworkChanges"
  namespace           = "CloudTrailMetrics-${var.prefix}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alerts on NACL, gateway, route table, or VPC configuration changes"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}
