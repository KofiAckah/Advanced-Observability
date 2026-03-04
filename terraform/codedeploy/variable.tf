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

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster (used by the CodeDeploy deployment group)"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service (used by the CodeDeploy deployment group)"
  type        = string
}

variable "blue_tg_name" {
  description = "Name of the blue ALB target group"
  type        = string
}

variable "green_tg_name" {
  description = "Name of the green ALB target group"
  type        = string
}

variable "prod_listener_arn" {
  description = "ARN of the ALB production listener (port 80)"
  type        = string
}

variable "test_listener_arn" {
  description = "ARN of the ALB test listener (port 8080) used by CodeDeploy to validate green"
  type        = string
}
