resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "vpc-${var.prefix}"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "igw-${var.prefix}"
  })
}

resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "subnet-app-${var.prefix}"
  })
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "rt-app-${var.prefix}"
  })
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.app.id
}

# Equivalent of the Azure NSG. Note: AWS Security Groups only support
# Allow rules (no Deny), so the Day 5 auto-block mechanism cannot use
# this resource — it will use a Network ACL instead (added at Day 5),
# which is stateless and supports explicit Deny rules with numeric
# ordering, matching the Azure NSG priority model.
resource "aws_security_group" "app" {
  name        = "sg-app-${var.prefix}"
  description = "Security group for the LearningSteps app instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH (locked down to specific IP on Day 1)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
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
    Name = "sg-app-${var.prefix}"
  })
}

# Day 4's RDS migration adds a dedicated private subnet for PostgreSQL here
# (aws_subnet.db, no route to the internet gateway), deliberately not part
# of the baseline. See docs/day4-data-isolation.md once written.
