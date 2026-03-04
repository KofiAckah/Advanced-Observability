# ==============================================
# Parameter Store Module Outputs
# ==============================================

output "parameter_names" {
  description = "Map of parameter names created in Parameter Store"
  value = {
    postgres_db          = aws_ssm_parameter.postgres_db.name
    postgres_user        = aws_ssm_parameter.postgres_user.name
    postgres_password    = aws_ssm_parameter.postgres_password.name
    backend_port         = aws_ssm_parameter.backend_port.name
    db_host              = aws_ssm_parameter.db_host.name
    db_port              = aws_ssm_parameter.db_port.name
    compose_project_name = aws_ssm_parameter.compose_project_name.name
    frontend_port        = aws_ssm_parameter.frontend_port.name
  }
}

output "parameter_arns" {
  description = "ARNs of all parameters created"
  value = [
    aws_ssm_parameter.postgres_db.arn,
    aws_ssm_parameter.postgres_user.arn,
    aws_ssm_parameter.postgres_password.arn,
    aws_ssm_parameter.backend_port.arn,
    aws_ssm_parameter.db_host.arn,
    aws_ssm_parameter.db_port.arn,
    aws_ssm_parameter.compose_project_name.arn,
    aws_ssm_parameter.frontend_port.arn,
  ]
}

output "parameter_path_prefix" {
  description = "Path prefix for all parameters"
  value       = "/${var.project_name}/${var.environment}/"
}
