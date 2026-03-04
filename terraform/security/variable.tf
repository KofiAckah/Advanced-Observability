variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "ssh_allowed_ip" {
  description = "The single IP address (CIDR) allowed to SSH into instances."
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

variable "vpc_cidr" {
  description = "VPC CIDR block – used to scope monitoring scrape rules to intra-VPC traffic"
  type        = string
  default     = "10.0.0.0/16"
}
