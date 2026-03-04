# ==============================================
# Parameter Store Module Variables
# ==============================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ==============================================
# Database Configuration Variables
# ==============================================

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "spendwise"
}

variable "postgres_user" {
  description = "PostgreSQL database user"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
}

# ==============================================
# Application Configuration Variables
# ==============================================

variable "backend_port" {
  description = "Backend API server port"
  type        = string
  default     = "5000"
}

variable "db_host" {
  description = "Database host (use 'postgres' for Docker)"
  type        = string
  default     = "postgres"
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "5432"
}

variable "compose_project_name" {
  description = "Docker Compose project name"
  type        = string
  default     = "spendwise"
}

variable "frontend_port" {
  description = "Frontend application port"
  type        = string
  default     = "5173"
}
