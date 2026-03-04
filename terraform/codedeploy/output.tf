output "codedeploy_app_name" {
  description = "Name of the CodeDeploy ECS application"
  value       = aws_codedeploy_app.main.name
}

output "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy ECS deployment group"
  value       = aws_codedeploy_deployment_group.main.deployment_group_name
}

output "appspec_s3_bucket" {
  description = "S3 bucket name where the pipeline uploads appspec.yml before each deployment"
  value       = aws_s3_bucket.appspec.id
}

output "codedeploy_role_arn" {
  description = "IAM role ARN granted to the CodeDeploy service"
  value       = aws_iam_role.codedeploy.arn
}
