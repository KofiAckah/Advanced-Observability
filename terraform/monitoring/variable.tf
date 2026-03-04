# ==============================================================
# terraform/monitoring/variable.tf
# ==============================================================

variable "project_name" {
  description = "Project name used for resource naming and tags."
  type        = string
  default     = "spendwise"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region where monitoring resources are deployed."
  type        = string
  default     = "eu-central-1"
}
