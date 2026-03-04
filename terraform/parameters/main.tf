# ==============================================
# AWS Systems Manager Parameter Store Resources
# ==============================================
# Stores SpendWise application configuration securely
# so Ansible can retrieve them on the app server at deploy time

# ==============================================
# Database Configuration Parameters
# ==============================================

resource "aws_ssm_parameter" "postgres_db" {
  name        = "/${var.project_name}/${var.environment}/db/name"
  description = "PostgreSQL database name for ${var.project_name}"
  type        = "String"
  value       = var.postgres_db

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-db-name"
      Parameter   = "DatabaseName"
      Environment = var.environment
    }
  )
}

resource "aws_ssm_parameter" "postgres_user" {
  name        = "/${var.project_name}/${var.environment}/db/user"
  description = "PostgreSQL database user for ${var.project_name}"
  type        = "SecureString"
  value       = var.postgres_user

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-db-user"
      Parameter   = "DatabaseUser"
      Environment = var.environment
    }
  )
}

resource "aws_ssm_parameter" "postgres_password" {
  name        = "/${var.project_name}/${var.environment}/db/password"
  description = "PostgreSQL database password for ${var.project_name}"
  type        = "SecureString"
  value       = var.postgres_password

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-db-password"
      Parameter   = "DatabasePassword"
      Environment = var.environment
    }
  )
}

# ==============================================
# Application Configuration Parameters
# ==============================================

resource "aws_ssm_parameter" "backend_port" {
  name        = "/${var.project_name}/${var.environment}/app/backend_port"
  description = "Backend API server port for ${var.project_name}"
  type        = "String"
  value       = var.backend_port

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-backend-port"
      Parameter   = "BackendPort"
      Environment = var.environment
    }
  )
}

resource "aws_ssm_parameter" "db_host" {
  name        = "/${var.project_name}/${var.environment}/app/db_host"
  description = "Database host for ${var.project_name}"
  type        = "String"
  value       = var.db_host

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-db-host"
      Parameter   = "DatabaseHost"
      Environment = var.environment
    }
  )
}

resource "aws_ssm_parameter" "db_port" {
  name        = "/${var.project_name}/${var.environment}/app/db_port"
  description = "Database port for ${var.project_name}"
  type        = "String"
  value       = var.db_port

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-db-port"
      Parameter   = "DatabasePort"
      Environment = var.environment
    }
  )
}

resource "aws_ssm_parameter" "compose_project_name" {
  name        = "/${var.project_name}/${var.environment}/app/compose_project_name"
  description = "Docker Compose project name for ${var.project_name}"
  type        = "String"
  value       = var.compose_project_name

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-compose-project"
      Parameter   = "ComposeProjectName"
      Environment = var.environment
    }
  )
}

resource "aws_ssm_parameter" "frontend_port" {
  name        = "/${var.project_name}/${var.environment}/app/frontend_port"
  description = "Frontend application port for ${var.project_name}"
  type        = "String"
  value       = var.frontend_port

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-frontend-port"
      Parameter   = "FrontendPort"
      Environment = var.environment
    }
  )
}
