# --- General Config ---
variable "aws_region" {
  description = "AWS Region to deploy resources (e.g., eu-central-1)"
  type        = string
}

variable "project_name" {
  description = "Project name prefix for tagging resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, stage, prod)"
  type        = string
}

# --- Networking ---
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

# --- Security ---
variable "ssh_allowed_ip" {
  description = "The single IP address (CIDR) allowed to SSH into instances. Use 0.0.0.0/0 for open access."
  type        = string
}

# --- Compute ---
variable "jenkins_instance_type" {
  description = "Instance type for Jenkins Server (Recommended: t3.medium)"
  type        = string
}

variable "app_instance_type" {
  description = "Instance type for Application Server (Recommended: t3.micro)"
  type        = string
}

variable "key_name" {
  description = "Name for the EC2 Key Pair to create in AWS (a new key pair will be generated)"
  type        = string
  default     = "SpendWise-KP"
}

# --- Application Config (passed to Ansible) ---
variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "spendwise"
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "spendwise_dev"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
  default     = "Dev@Spend2024!"
}

variable "backend_port" {
  description = "Port for the backend API"
  type        = string
  default     = "5000"
}

variable "monitoring_instance_type" {
  description = "Instance type for the Monitoring Server (Prometheus + Grafana). Recommended: t3.small"
  type        = string
  default     = "t3.small"
}

variable "db_host" {
  description = "Database host (postgres for Docker Compose)"
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
  description = "Port for the frontend (5173 for Vite dev, 80 for prod)"
  type        = string
  default     = "5173"
}

# --- Tags ---
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

# ==============================================================
# ECS & RDS Variables
# ==============================================================

variable "db_name" {
  description = "RDS PostgreSQL database name"
  type        = string
  default     = "spendwise"
}

variable "db_username" {
  description = "RDS PostgreSQL master username"
  type        = string
  default     = "spendwise_admin"
}

variable "db_password" {
  description = "RDS PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Docker image tag for ECS (e.g., latest, v1.0.0, or build number)"
  type        = string
  default     = "latest"
}