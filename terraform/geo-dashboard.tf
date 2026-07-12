resource "aws_cloudwatch_dashboard" "security" {
  dashboard_name = "learningsteps-security-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Blocked Attackers by Country"
          view   = "pie"
          region = var.aws_region
          metrics = [
            ["LearningSteps/CrowdSec", "BlockedAttackers", "Country", "DE"],
            ["LearningSteps/CrowdSec", "BlockedAttackers", "Country", "US"],
            ["LearningSteps/CrowdSec", "BlockedAttackers", "Country", "CH"],
            ["LearningSteps/CrowdSec", "BlockedAttackers", "Country", "NL"],
            ["LearningSteps/CrowdSec", "BlockedAttackers", "Country", "Unknown"]
          ]
          stat = "Maximum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "WAF Blocks Over Time"
          view   = "timeSeries"
          region = var.aws_region
          metrics = [
            ["LearningSteps/CrowdSec", "BlockedAttackers", "Country", "DE"],
            ["LearningSteps/CrowdSec", "BlockedAttackers", "Country", "US"],
            ["LearningSteps/CrowdSec", "BlockedAttackers", "Country", "CH"],
            ["LearningSteps/CrowdSec", "BlockedAttackers", "Country", "NL"]
          ]
          stat   = "Sum"
          period = 3600
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Recent WAF Blocks"
          region = var.aws_region
          query  = "SOURCE '/learningsteps/learningsteps/nginx' | fields @timestamp, remote_addr, uri, status | filter status = 403 | sort @timestamp desc | limit 20"
          view   = "table"
        }
      }
    ]
  })
}
