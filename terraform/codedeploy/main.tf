# ==============================================================
# terraform/codedeploy/main.tf
# AWS CodeDeploy blue/green deployment for SpendWise ECS service
# ==============================================================

data "aws_caller_identity" "current" {}

# ==============================================================
# S3 Bucket  — stores appspec.yml uploaded by Jenkins per build
# ==============================================================

resource "aws_s3_bucket" "appspec" {
  # Bucket name must be globally unique; include account ID for uniqueness
  bucket        = "spendwise-${var.environment}-cd-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "spendwise-${var.environment}-codedeploy-appspec"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "appspec" {
  bucket = aws_s3_bucket.appspec.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "appspec" {
  bucket                  = aws_s3_bucket.appspec.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "appspec" {
  bucket = aws_s3_bucket.appspec.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ==============================================================
# SSM Parameters — pipeline reads these instead of hardcoding
# ==============================================================

resource "aws_ssm_parameter" "codedeploy_s3_bucket" {
  name      = "/${var.project_name}/${var.environment}/codedeploy/s3_bucket"
  type      = "String"
  value     = aws_s3_bucket.appspec.id
  overwrite = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "codedeploy_app_name" {
  name      = "/${var.project_name}/${var.environment}/codedeploy/app_name"
  type      = "String"
  value     = aws_codedeploy_app.main.name
  overwrite = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "codedeploy_deployment_group" {
  name      = "/${var.project_name}/${var.environment}/codedeploy/deployment_group"
  type      = "String"
  value     = aws_codedeploy_deployment_group.main.deployment_group_name
  overwrite = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ==============================================================
# IAM Role — assumed by the CodeDeploy service (not by humans)
# ==============================================================

resource "aws_iam_role" "codedeploy" {
  name = "${var.project_name}-${var.environment}-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-codedeploy-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# AWS-managed policy that grants CodeDeploy all ECS blue/green permissions
resource "aws_iam_role_policy_attachment" "codedeploy_ecs" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# Allow CodeDeploy service role to read appspec from S3
resource "aws_iam_role_policy" "codedeploy_s3" {
  name = "${var.project_name}-${var.environment}-codedeploy-s3"
  role = aws_iam_role.codedeploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.appspec.arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetBucketLocation"]
        Resource = aws_s3_bucket.appspec.arn
      }
    ]
  })
}

# ==============================================================
# Jenkins IAM Role — add CodeDeploy + S3 appspec permissions
# Lookup existing Jenkins role (created in security module)
# ==============================================================

data "aws_iam_role" "jenkins" {
  name = "${var.project_name}-${var.environment}-jenkins-role"
}

resource "aws_iam_role_policy" "jenkins_codedeploy" {
  name = "${var.project_name}-${var.environment}-jenkins-codedeploy"
  role = data.aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 — upload and read appspec.yml revisions
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.appspec.arn,
          "${aws_s3_bucket.appspec.arn}/*"
        ]
      },
      # CodeDeploy — create and monitor deployments
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetDeploymentGroup",
          "codedeploy:ListDeployments",
          "codedeploy:ListDeploymentGroups",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplicationRevision",
          "codedeploy:ListApplicationRevisions",
          "codedeploy:GetApplication"
        ]
        Resource = "*"
      }
    ]
  })
}

# ==============================================================
# CodeDeploy Application (ECS platform)
# ==============================================================

resource "aws_codedeploy_app" "main" {
  name             = "${var.project_name}-${var.environment}-codedeploy-app"
  compute_platform = "ECS"

  tags = {
    Name        = "${var.project_name}-${var.environment}-codedeploy-app"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ==============================================================
# CodeDeploy Deployment Group (blue/green ECS)
# ==============================================================

resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "${var.project_name}-${var.environment}-dg"
  # ECSAllAtOnce: immediately shifts 100% traffic to green after health checks pass.
  # Use ECSLinear10PercentEvery1Minutes for a safer canary-style shift in production.
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  # Auto-rollback shifts traffic back to blue on deployment failure
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    # Immediately shift traffic — no manual approval step required
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    # Terminate old (blue) tasks 5 minutes after successful green cutover
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL" # Shift via ALB listeners
    deployment_type   = "BLUE_GREEN"
  }

  # Which ECS cluster + service to deploy into
  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.ecs_service_name
  }

  # ALB listener + target group pair for traffic shifting
  load_balancer_info {
    target_group_pair_info {
      # Production listener (port 80): receives live traffic
      prod_traffic_route {
        listener_arns = [var.prod_listener_arn]
      }

      # Test listener (port 8080): CodeDeploy routes here to smoke-test green first
      test_traffic_route {
        listener_arns = [var.test_listener_arn]
      }

      # Blue = currently serving production traffic
      target_group {
        name = var.blue_tg_name
      }

      # Green = receives the new task revision
      target_group {
        name = var.green_tg_name
      }
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.codedeploy_ecs,
    aws_iam_role_policy.codedeploy_s3
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-dg"
    Project     = var.project_name
    Environment = var.environment
  }
}
