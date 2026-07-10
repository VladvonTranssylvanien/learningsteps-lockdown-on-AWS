output "vm_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.vm.public_ip
}

output "vm_instance_id" {
  description = "Instance ID, used for SSM Session Manager connections"
  value       = aws_instance.vm.id
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "ssm_connect_command" {
  description = "Command to connect to the VM via SSM (no SSH key needed)"
  value       = "aws ssm start-session --target ${aws_instance.vm.id} --region ${var.aws_region}"
}
