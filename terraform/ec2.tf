data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.app.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.vm.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yaml", {
    secret_name       = aws_secretsmanager_secret.db_password.name
    aws_region        = var.aws_region
    db_admin_username = var.db_admin_username
    db_host           = aws_db_instance.main.address
    db_name           = var.db_name
  }))

  depends_on = [
    aws_db_instance.main,
  ]

  tags = merge(local.common_tags, {
    Name = "vm-${var.prefix}"
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
