output "jenkins_public_ip" {
  description = "Public IP of the Jenkins Server"
  value       = aws_instance.jenkins_server.public_ip
}

output "app_public_ip" {
  description = "Public IP of the App Server"
  value       = aws_instance.app_server.public_ip
}

output "jenkins_instance_id" {
  description = "Instance ID of the Jenkins Server"
  value       = aws_instance.jenkins_server.id
}

output "app_instance_id" {
  description = "Instance ID of the App Server"
  value       = aws_instance.app_server.id
}

output "monitoring_server_public_ip" {
  description = "Public IP of the Monitoring Server (Prometheus + Grafana)"
  value       = aws_instance.monitoring_server.public_ip
}

output "monitoring_server_instance_id" {
  description = "Instance ID of the Monitoring Server"
  value       = aws_instance.monitoring_server.id
}

output "app_server_private_ip" {
  description = "Private IP of the App Server – used by Prometheus for intra-VPC scraping"
  value       = aws_instance.app_server.private_ip
}

output "iam_role_name" {
  description = "IAM role attached to the app server EC2 instance"
  value       = aws_iam_role.spendwise_ec2_role.name
}

output "instance_profile_name" {
  description = "IAM instance profile name attached to the app server"
  value       = aws_iam_instance_profile.ec2_profile.name
}
