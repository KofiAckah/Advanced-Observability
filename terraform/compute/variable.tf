variable "project_name" {
  description = "Project name prefix for tagging resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, stage, prod)"
  type        = string
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins Server"
  type        = string
}

variable "app_instance_type" {
  description = "Instance type for Application Server"
  type        = string
}

variable "key_name" {
  description = "Name of the existing EC2 Key Pair in AWS"
  type        = string
}

variable "public_subnet_id" {
  description = "The ID of the public subnet"
  type        = string
}

variable "jenkins_sg_id" {
  description = "Security Group ID for Jenkins"
  type        = string
}

variable "app_sg_id" {
  description = "Security Group ID for App"
  type        = string
}

variable "jenkins_instance_profile" {
  description = "IAM Instance Profile for Jenkins"
  type        = string
}

variable "app_instance_profile" {
  description = "IAM Instance Profile for App"
  type        = string
}

variable "monitoring_instance_type" {
  description = "Instance type for the Monitoring Server (Prometheus + Grafana). Recommended: t3.small"
  type        = string
  default     = "t3.small"
}

variable "monitoring_sg_id" {
  description = "Security Group ID for the Monitoring Server"
  type        = string
}
