output "rds_endpoint" {
  description = "DNS endpoint of the RDS instance."
  value       = aws_db_instance.mysql.address
}

output "rds_port" {
  description = "Port for remote MySQL connections."
  value       = aws_db_instance.mysql.port
}

output "database_name" {
  description = "Initial database name."
  value       = aws_db_instance.mysql.db_name
}

output "master_username" {
  description = "Master username."
  value       = aws_db_instance.mysql.username
}

output "master_password" {
  description = "Master password (sensitive)."
  value       = local.master_password
  sensitive   = true
}
