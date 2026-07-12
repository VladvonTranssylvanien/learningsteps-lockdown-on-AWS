#!/bin/bash
# Day 5 — CloudWatch log forwarding for NPMplus access logs.
# Routes local0 syslog (written by npmplus-log-forwarder.py, see
# setup-json-logging.sh) into a clean JSON file, then ships it to
# CloudWatch Logs via the Amazon CloudWatch Agent.
set -euo pipefail

echo "==> Configuring rsyslog to route local0 -> clean JSON file..."
cat > /etc/rsyslog.d/30-nginx-json.conf << 'RSYSLOG_EOF'
$template JustMsg,"%msg:2:$%\n"
local0.* /var/log/nginx-json.log;JustMsg
RSYSLOG_EOF
systemctl restart rsyslog

echo "==> Installing CloudWatch Agent..."
curl -fsSL https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -o /tmp/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb

echo "==> Writing CloudWatch Agent config..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CONFIG_EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx-json.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%d/%b/%Y:%H:%M:%S"
          }
        ]
      }
    }
  }
}
CONFIG_EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "Done. CloudWatch Agent forwarding /var/log/nginx-json.log to ${log_group_name}."
