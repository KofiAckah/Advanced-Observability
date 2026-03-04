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

output "alb_sg_id" {
  description = "Security Group ID of the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (public entry point for the app)"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "blue_tg_arn" {
  description = "ARN of the blue target group"
  value       = aws_lb_target_group.blue.arn
}

output "blue_tg_name" {
  description = "Name of the blue target group (used by CodeDeploy deployment group)"
  value       = aws_lb_target_group.blue.name
}

output "green_tg_arn" {
  description = "ARN of the green target group"
  value       = aws_lb_target_group.green.arn
}

output "green_tg_name" {
  description = "Name of the green target group (used by CodeDeploy deployment group)"
  value       = aws_lb_target_group.green.name
}

output "prod_listener_arn" {
  description = "ARN of the production ALB listener (port 80)"
  value       = aws_lb_listener.prod.arn
}

output "test_listener_arn" {
  description = "ARN of the test ALB listener (port 8080, used by CodeDeploy to validate green)"
  value       = aws_lb_listener.test.arn
}
