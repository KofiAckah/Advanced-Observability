output "backend_repository_url" {
  description = "The URL of the backend ECR repository"
  value       = aws_ecr_repository.backend_repo.repository_url
}

output "frontend_repository_url" {
  description = "The URL of the frontend ECR repository"
  value       = aws_ecr_repository.frontend_repo.repository_url
}

output "backend_repository_arn" {
  description = "The ARN of the backend ECR repository"
  value       = aws_ecr_repository.backend_repo.arn
}

output "frontend_repository_arn" {
  description = "The ARN of the frontend ECR repository"
  value       = aws_ecr_repository.frontend_repo.arn
}
