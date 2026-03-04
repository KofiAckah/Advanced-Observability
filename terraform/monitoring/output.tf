# ==============================================================
# terraform/monitoring/output.tf
# ==============================================================

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for SpendWise application logs."
  value       = aws_cloudwatch_log_group.app.name
}

output "cloudtrail_s3_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs."
  value       = aws_s3_bucket.cloudtrail.id
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector for this account/region."
  value       = aws_guardduty_detector.main.id
}
