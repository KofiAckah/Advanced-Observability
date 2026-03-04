output "db_address" {
  description = "RDS database address (hostname)"
  value       = aws_db_instance.main.address
}

output "db_endpoint" {
  description = "RDS database endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "db_port" {
  description = "RDS database port"
  value       = aws_db_instance.main.port
}

output "rds_security_group_id" {
  description = "Security group ID of the RDS instance"
  value       = aws_security_group.rds_sg.id
}

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "db_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}
