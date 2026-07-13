# Public by design at baseline — matching the Azure original's insecure
# starting point. Day 4 migrates this to a private subnet with no public
# access, mirroring the Azure Private Link migration.
resource "aws_security_group" "db" {
  name        = "db-sg-${var.prefix}"
  description = "Security group for the LearningSteps database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL restricted to app tier only, network-layer mitigation ahead of Day 4 private-subnet migration"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "sg-db-${var.prefix}"
  })
}

# Storage reduced to 20GB vs. the Azure original's 32GB — RDS Free Tier
# covers 20GB only; going higher would consume paid credit. Documented
# cost-driven deviation.
resource "aws_db_instance" "main" {
  identifier                = "psql-${var.prefix}"
  engine                    = "postgres"
  engine_version            = "16"
  instance_class            = "db.t3.micro"
  allocated_storage         = 20
  storage_type              = "gp2"
  storage_encrypted         = true
  kms_key_id                = aws_kms_key.rds.arn
  db_name                   = var.db_name
  username                  = var.db_admin_username
  password                  = var.db_admin_password
  publicly_accessible       = false
  apply_immediately         = true
  vpc_security_group_ids    = [aws_security_group.db.id]
  db_subnet_group_name      = aws_db_subnet_group.main.name
  parameter_group_name      = aws_db_parameter_group.postgres16.name
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "psql-${var.prefix}-final"
  copy_tags_to_snapshot     = true

  # RDS automated backups are free up to the allocated storage size —
  # this was previously unset, which defaults to 0 (backups off).
  # This account's free-tier restriction caps retention at 1 day; the
  # AWS Backup plan in backup.tf provides the real 7-day coverage.
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Free on db.t3/t2.micro with the default 7-day retention.
  performance_insights_enabled = true

  tags = local.common_tags
}

# rds.force_ssl is a static parameter: it only takes effect after the
# next reboot, so this queues the change without an immediate restart.
resource "aws_db_parameter_group" "postgres16" {
  name   = "psql-${var.prefix}-force-ssl"
  family = "postgres16"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = local.common_tags
}

resource "aws_subnet" "db_primary" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "subnet-db-primary-${var.prefix}"
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "dbsubnet-${var.prefix}"
  subnet_ids = [aws_subnet.db_primary.id, aws_subnet.db_secondary.id]

  tags = local.common_tags
}
