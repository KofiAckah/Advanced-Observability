output "jenkins_sg_id" {
  description = "Security Group ID for Jenkins"
  value       = aws_security_group.jenkins_sg.id
}

output "app_sg_id" {
  description = "Security Group ID for App"
  value       = aws_security_group.app_sg.id
}

output "jenkins_profile_name" {
  description = "IAM Instance Profile name for Jenkins"
  value       = aws_iam_instance_profile.jenkins_profile.name
}

output "app_profile_name" {
  description = "IAM Instance Profile name for App"
  value       = aws_iam_instance_profile.app_profile.name
}

output "monitoring_sg_id" {
  description = "Security Group ID for the Monitoring Server"
  value       = aws_security_group.monitoring_sg.id
}
