output "vpc_id" {
  description = "The ID of the VPC created in the networking module"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "The ID of the public subnet created in the networking module"
  value       = module.networking.public_subnet_id
}

output "jenkins_sg_id" {
  description = "Security Group ID for Jenkins"
  value       = module.security.jenkins_sg_id
}

output "app_sg_id" {
  description = "Security Group ID for App"
  value       = module.security.app_sg_id
}

output "backend_ecr_repository_url" {
  description = "The URL of the backend ECR repository"
  value       = module.ecr.backend_repository_url
}

output "frontend_ecr_repository_url" {
  description = "The URL of the frontend ECR repository"
  value       = module.ecr.frontend_repository_url
}

output "jenkins_public_ip" {
  description = "Public IP of the Jenkins Server"
  value       = module.compute.jenkins_public_ip
}

output "app_public_ip" {
  description = "Public IP of the App Server"
  value       = module.compute.app_public_ip
}

output "jenkins_instance_id" {
  description = "Instance ID of the Jenkins Server"
  value       = module.compute.jenkins_instance_id
}

output "app_instance_id" {
  description = "Instance ID of the App Server"
  value       = module.compute.app_instance_id
}

output "parameter_store_path" {
  description = "Parameter Store path prefix for application configuration"
  value       = module.parameters.parameter_path_prefix
}

output "parameter_names" {
  description = "Map of parameter names in Parameter Store"
  value       = module.parameters.parameter_names
}

output "monitoring_server_public_ip" {
  description = "Public IP of the Monitoring Server (Prometheus + Grafana)"
  value       = module.compute.monitoring_server_public_ip
}

output "monitoring_server_instance_id" {
  description = "Instance ID of the Monitoring Server"
  value       = module.compute.monitoring_server_instance_id
}

output "monitoring_sg_id" {
  description = "Security Group ID for the Monitoring Server"
  value       = module.security.monitoring_sg_id
}

# ==============================================================
# Monitoring module outputs (CloudWatch / CloudTrail / GuardDuty)
# ==============================================================
output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name for SpendWise application logs."
  value       = module.monitoring.cloudwatch_log_group_name
}

output "cloudtrail_s3_bucket_name" {
  description = "S3 bucket name used by the spendwise-trail CloudTrail."
  value       = module.monitoring.cloudtrail_s3_bucket_name
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID for this account/region."
  value       = module.monitoring.guardduty_detector_id
}

# ==============================================================
# ECS module outputs
# ==============================================================
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "ecs_task_definition_family" {
  description = "Family name of the ECS task definition"
  value       = module.ecs.task_definition_family
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.ecs.task_definition_arn
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = module.ecs.ecs_security_group_id
}

output "ecs_cloudwatch_log_group" {
  description = "CloudWatch log group for ECS containers"
  value       = module.ecs.cloudwatch_log_group
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.ecs.execution_role_arn
}

# ==============================================================
# RDS module outputs
# ==============================================================
output "rds_endpoint" {
  description = "Connection endpoint for the RDS database"
  value       = module.rds.db_endpoint
}

output "rds_address" {
  description = "Hostname/address of the RDS database"
  value       = module.rds.db_address
}

output "rds_database_name" {
  description = "Name of the database"
  value       = module.rds.db_name
}

output "rds_security_group_id" {
  description = "Security group ID for RDS database"
  value       = module.rds.rds_security_group_id
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.db_instance_id
}
