# Public by design at baseline — matching the Azure original's insecure
# starting point. Day 4 migrates this to a private subnet with no public
# access, mirroring the Azure Private Link migration.
resource "aws_security_group" "db" {
  name        = "db-sg-${var.prefix}"
  description = "Security group for the LearningSteps database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL (open to any IP at baseline, insecure by design)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
  identifier             = "psql-${var.prefix}"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.db_name
  username               = var.db_admin_username
  password               = var.db_admin_password
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  skip_final_snapshot    = true

  tags = local.common_tags
}

resource "aws_db_subnet_group" "main" {
  name       = "dbsubnet-${var.prefix}"
  subnet_ids = [aws_subnet.app.id, aws_subnet.db_secondary.id]

  tags = local.common_tags
}
