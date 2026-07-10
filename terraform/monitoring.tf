# ── CloudWatch Log Group ────────────────────────────────────────────────────
# Equivalent of the Log Analytics Workspace
resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/learningsteps/${var.prefix}/nginx"
  retention_in_days = 30

  tags = local.common_tags
}

# CloudWatch agent needs this on the EC2 role to ship logs
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.vm.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ── Network ACL ──────────────────────────────────────────────────────────────
# Security Groups (network.tf) only support Allow rules. The auto-block
# mechanism needs Deny, which only Network ACLs support in AWS — this is
# the equivalent of the Azure NSG's deny-rule auto-block. Rule numbers
# below 100 are reserved for the Lambda-created deny rules, matching the
# Azure original's "priorities 100-199 reserved for auto-block" pattern.
resource "aws_network_acl" "app" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.app.id]

  ingress {
    rule_no    = 1000
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }
  ingress {
    rule_no    = 1010
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  ingress {
    rule_no    = 1020
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  ingress {
    rule_no    = 1030
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 1000
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "nacl-app-${var.prefix}"
  })
}

# ── Lambda: WAF Attack Detector + Auto-Block ────────────────────────────────
# Combines Sentinel's Analytics Rule (detection) and Logic App playbook
# (response) into a single function, since AWS has no direct Sentinel
# equivalent. Same 5-block threshold, same 127.0.0.1 exclusion logic as
# the Azure original (see scripts/waf-attack-detector/handler.py).
data "archive_file" "waf_detector" {
  type        = "zip"
  source_dir  = "${path.module}/scripts/waf-attack-detector"
  output_path = "${path.module}/scripts/waf-attack-detector.zip"
}

resource "aws_iam_role" "waf_detector" {
  name = "role-${var.prefix}-waf-detector"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "waf_detector_basic" {
  role       = aws_iam_role.waf_detector.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "waf_detector_permissions" {
  name = "waf-detector-permissions"
  role = aws_iam_role.waf_detector.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:GetQueryResults",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeNetworkAcls",
          "ec2:CreateNetworkAclEntry",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "waf_detector" {
  function_name    = "${var.prefix}-waf-detector"
  role             = aws_iam_role.waf_detector.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.waf_detector.output_path
  source_code_hash = data.archive_file.waf_detector.output_base64sha256

  environment {
    variables = {
      LOG_GROUP_NAME = aws_cloudwatch_log_group.nginx.name
      NACL_ID        = aws_network_acl.app.id
    }
  }

  tags = local.common_tags
}

# Runs every 5 minutes, same cadence as the Sentinel scheduled rule
resource "aws_cloudwatch_event_rule" "waf_detector_schedule" {
  name                = "${var.prefix}-waf-detector-schedule"
  schedule_expression = "rate(5 minutes)"

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "waf_detector" {
  rule      = aws_cloudwatch_event_rule.waf_detector_schedule.name
  target_id = "waf-detector"
  arn       = aws_lambda_function.waf_detector.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.waf_detector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.waf_detector_schedule.arn
}
