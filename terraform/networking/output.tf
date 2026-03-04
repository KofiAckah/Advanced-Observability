output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (for ECS)"
  value       = [aws_subnet.public.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (for RDS)"
  value       = aws_subnet.private[*].id
}
