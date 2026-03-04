data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Ubuntu 24.04 LTS (Noble Numbat) – used for the monitoring node
data "aws_ami" "ubuntu_24_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "jenkins_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.jenkins_instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.jenkins_sg_id]
  iam_instance_profile   = var.jenkins_instance_profile

  root_block_device {
    volume_size           = 25    # GB – accommodate CodeQL databases and build artifacts
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-${var.environment}-jenkins-root"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-server"
  }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.app_instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.app_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "${var.project_name}-${var.environment}-app-server"
  }
}

# ==============================================
# IAM Role for App Server – CloudWatch Logs + ECR + SSM
# Grants the app EC2 instance permission to:
#   - Write container logs via the Docker awslogs driver  → CloudWatchLogsFullAccess
#   - Pull images from ECR                               → AmazonEC2ContainerRegistryReadOnly
#   - Fetch secrets from Parameter Store                 → AmazonSSMReadOnlyAccess
# ==============================================
resource "aws_iam_role" "spendwise_ec2_role" {
  name        = "spendwise-ec2-role"
  description = "EC2 instance role for SpendWise app server"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_full" {
  role       = aws_iam_role.spendwise_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.spendwise_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm_readonly" {
  role       = aws_iam_role.spendwise_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "spendwise-ec2-profile"
  role = aws_iam_role.spendwise_ec2_role.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-profile"
    Environment = var.environment
  }
}

# ==============================================
# Monitoring Server (Prometheus + Grafana)
# Ubuntu 24.04 LTS – dedicated observability node
# ==============================================
resource "aws_instance" "monitoring_server" {
  ami                    = data.aws_ami.ubuntu_24_04.id
  instance_type          = var.monitoring_instance_type
  key_name               = var.key_name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.monitoring_sg_id]

  root_block_device {
    volume_size           = 20    # GB – stores 30 days of Prometheus TSDB
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-${var.environment}-monitoring-root"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-monitoring-server"
    Role = "observability"
  }
}
