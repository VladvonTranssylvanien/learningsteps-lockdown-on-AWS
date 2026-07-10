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
    database_url = "postgresql://${var.db_admin_username}:${var.db_admin_password}@${aws_db_instance.main.address}/${var.db_name}?sslmode=require"
  }))

  depends_on = [
    aws_db_instance.main,
  ]

  tags = merge(local.common_tags, {
    Name = "vm-${var.prefix}"
  })
}
