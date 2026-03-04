# ==============================================================
# terraform/monitoring/main.tf
# AWS observability resources for SpendWise:
#   - CloudWatch Log Group  (/spendwise/app, 30-day retention)
#   - S3 Bucket             (CloudTrail logs, AES256, 90-day expiry)
#   - CloudTrail            (spendwise-trail, global events enabled)
#   - GuardDuty Detector    (enabled, FIFTEEN_MINUTES publish frequency)
#
# IMPORTANT – GuardDuty:
#   AWS allows only ONE detector per account per region.
#   If a detector already exists, import it before applying:
#     terraform import -var-file=../dev.tfvars \
#       module.monitoring.aws_guardduty_detector.main <detector-id>
# ==============================================================

# ---------------------------------------------------------------
# Dynamic account / region lookup (avoids hard-coding)
# ---------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ==============================================================
# CloudWatch Log Group – application logs
# ==============================================================
resource "aws_cloudwatch_log_group" "app" {
  name              = "/spendwise/app"
  retention_in_days = 30

  tags = {
    Name        = "/spendwise/app"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ==============================================================
# S3 Bucket – CloudTrail log storage
# ==============================================================
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "spendwise-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "spendwise-cloudtrail"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption using AES256
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy – expire logs after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "expire-logs-after-90-days"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# Bucket policy – allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  # public-access block must be in place before policy attachment
  depends_on = [aws_s3_bucket_public_access_block.cloudtrail]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# ==============================================================
# CloudTrail – management event trail
# ==============================================================
resource "aws_cloudtrail" "main" {
  name                          = "spendwise-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  # Bucket policy must exist before the trail is created
  depends_on = [aws_s3_bucket_policy.cloudtrail]

  tags = {
    Name        = "spendwise-trail"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ==============================================================
# GuardDuty Detector
# ==============================================================
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Name        = "spendwise-guardduty"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ==============================================================
# CloudWatch Alarms — SpendWise ECS / RDS / Deployment
# ==============================================================

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilisation above 80% for 2 consecutive minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = "${var.project_name}-${var.environment}-cluster"
    ServiceName = "${var.project_name}-${var.environment}-service"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-cpu-high"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS memory utilisation above 80% for 2 consecutive minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = "${var.project_name}-${var.environment}-cluster"
    ServiceName = "${var.project_name}-${var.environment}-service"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-memory-high"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_no_running_tasks" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-no-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "ECS service has 0 running tasks — app is down"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = "${var.project_name}-${var.environment}-cluster"
    ServiceName = "${var.project_name}-${var.environment}-service"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-no-running-tasks"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_metric_filter" "backend_errors" {
  name           = "${var.project_name}-${var.environment}-backend-5xx"
  pattern        = "ERROR"
  log_group_name = "/ecs/${var.project_name}-${var.environment}"

  metric_transformation {
    name          = "Backend5xxErrors"
    namespace     = "${var.project_name}/${var.environment}"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_errors_high" {
  alarm_name          = "${var.project_name}-${var.environment}-backend-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Backend5xxErrors"
  namespace           = "${var.project_name}/${var.environment}"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Backend returned more than 10 5xx errors in 1 minute"
  treat_missing_data  = "notBreaching"

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-5xx-high"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilisation above 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = "${var.project_name}-${var.environment}-db"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-cpu-high"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 1073741824 # 1 GB in bytes
  alarm_description   = "RDS free storage below 1 GB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = "${var.project_name}-${var.environment}-db"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-storage-low"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "deployment_failures" {
  alarm_name          = "${var.project_name}-${var.environment}-deployment-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DeploymentFailures"
  namespace           = "${var.project_name}/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "A Jenkins deployment to ECS failed — pipeline blocked by security gate or ECS error"
  treat_missing_data  = "notBreaching"

  tags = {
    Name        = "${var.project_name}-${var.environment}-deployment-failures"
    Project     = var.project_name
    Environment = var.environment
  }
}
