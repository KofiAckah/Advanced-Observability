variable "project_name" {
  description = "Project name prefix for tagging resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, stage, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ECS will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ECS tasks"
  type        = list(string)
}

variable "backend_image" {
  description = "Backend Docker image URL from ECR"
  type        = string
}

variable "frontend_image" {
  description = "Frontend Docker image URL from ECR"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "jaeger_endpoint" {
  description = "OTLP HTTP endpoint for Jaeger trace ingest (e.g. http://<monitoring-private-ip>:4318)"
  type        = string
  default     = "http://localhost:4318"
}

variable "db_name" {
  description = "Database name for backend environment variable"
  type        = string
}
