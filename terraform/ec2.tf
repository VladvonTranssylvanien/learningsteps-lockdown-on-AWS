data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "vm" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = "t3.small"
  subnet_id               = aws_subnet.app.id
  vpc_security_group_ids  = [aws_security_group.app.id]
  iam_instance_profile    = aws_iam_instance_profile.vm.name
  disable_api_termination = true
  monitoring              = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
    kms_key_id  = aws_kms_key.rds.arn
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yaml", {
    secret_name                     = aws_secretsmanager_secret.db_password.name
    aws_region                      = var.aws_region
    db_admin_username               = var.db_admin_username
    db_host                         = aws_db_instance.main.address
    db_name                         = var.db_name
    log_group_name                  = aws_cloudwatch_log_group.nginx.name
    setup_npmplus_script            = replace(file("${path.module}/scripts/setup-npmplus.sh"), "$${", "$$${")
    setup_json_logging_script       = replace(file("${path.module}/scripts/setup-json-logging.sh"), "$${", "$$${")
    setup_cloudwatch_logging_script = replace(file("${path.module}/scripts/setup-cloudwatch-logging.sh"), "$${", "$$${")
  }))

  depends_on = [
    aws_db_instance.main,
  ]

  tags = merge(local.common_tags, {
    Name          = "vm-${var.prefix}"
    "Patch Group" = "learningsteps-${var.prefix}"
  })
}

# Elastic IP: keeps the public IP stable across stop/start cycles.
# Without this, every restart gets a new IP, breaking the TLS cert
# (bound to <ip>.nip.io), the Cognito callback URL, and the
# oauth2-proxy redirect-url, all of which would need manual updates.
# Free while attached to a running instance.

resource "aws_eip" "vm" {
  instance = aws_instance.vm.id
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "eip-${var.prefix}-vm"
  })
}

# Free EC2-native auto-recovery: if the underlying host fails a system
# status check, AWS migrates the instance to new hardware automatically.
resource "aws_cloudwatch_metric_alarm" "vm_status_check" {
  alarm_name          = "vm-status-check-failed-${var.prefix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Triggers EC2 auto-recovery when the system status check fails"
  alarm_actions       = ["arn:aws:automate:${var.aws_region}:ec2:recover"]
  dimensions = {
    InstanceId = aws_instance.vm.id
  }

  tags = local.common_tags
}
