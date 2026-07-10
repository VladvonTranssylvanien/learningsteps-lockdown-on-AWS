locals {
  common_tags = {
    Project     = var.prefix
    Environment = "learning"
    ManagedBy   = "terraform"
  }
}
