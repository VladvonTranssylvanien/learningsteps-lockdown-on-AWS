variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "learningsteps"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vm_admin_username" {
  description = "Admin username for the EC2 instance"
  type        = string
  default     = "ubuntu"
}

variable "db_admin_username" {
  description = "Administrator username for PostgreSQL"
  type        = string
  default     = "psqladmin"
}

variable "db_admin_password" {
  description = "Administrator password for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the application database"
  type        = string
  default     = "learning_journal"
}
