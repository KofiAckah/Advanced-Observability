# --- Key Pair ---
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = var.key_name
  }
}

# Save private key in the terraform directory
resource "local_sensitive_file" "private_key_terraform" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}

# Save a copy in the Ansible directory for playbook use
resource "local_sensitive_file" "private_key_ansible" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${path.module}/../Ansible/${var.key_name}.pem"
  file_permission = "0400"
}

module "networking" {
  source = "./networking"

  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  project_name       = var.project_name
  environment        = var.environment
}

module "security" {
  source = "./security"

  vpc_id         = module.networking.vpc_id
  vpc_cidr       = var.vpc_cidr
  ssh_allowed_ip = var.ssh_allowed_ip
  project_name   = var.project_name
  environment    = var.environment
}

module "ecr" {
  source = "./ecr"

  project_name = var.project_name
  environment  = var.environment
}

# ==============================================
# Parameter Store Module
# ==============================================
module "parameters" {
  source = "./parameters"

  project_name         = var.project_name
  environment          = var.environment
  postgres_db          = var.postgres_db
  postgres_user        = var.postgres_user
  postgres_password    = var.postgres_password
  backend_port         = var.backend_port
  db_host              = module.rds.db_address
  db_port              = var.db_port
  compose_project_name = var.compose_project_name
  frontend_port        = var.frontend_port
  common_tags          = var.common_tags
}

module "compute" {
  source = "./compute"

  project_name             = var.project_name
  environment              = var.environment
  jenkins_instance_type    = var.jenkins_instance_type
  app_instance_type        = var.app_instance_type
  monitoring_instance_type = var.monitoring_instance_type
  key_name                 = aws_key_pair.main.key_name
  public_subnet_id         = module.networking.public_subnet_id
  jenkins_sg_id            = module.security.jenkins_sg_id
  app_sg_id                = module.security.app_sg_id
  monitoring_sg_id         = module.security.monitoring_sg_id
  jenkins_instance_profile = module.security.jenkins_profile_name
  app_instance_profile     = module.security.app_profile_name
}

# ==============================================================
# Monitoring Module – CloudWatch, CloudTrail, GuardDuty
# ==============================================================
module "monitoring" {
  source = "./monitoring"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

# ==============================================================
# ECS Module – Fargate cluster, task definition, and service
# ==============================================================
module "ecs" {
  source = "./ecs"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  backend_image      = module.ecr.backend_repository_url
  frontend_image     = module.ecr.frontend_repository_url
  image_tag          = var.image_tag
  db_name            = var.db_name
}

# ==============================================================
# RDS Module – PostgreSQL database for SpendWise application
# ==============================================================
module "rds" {
  source = "./rds"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  vpc_id                 = module.networking.vpc_id
  private_subnet_ids     = module.networking.private_subnet_ids
  ecs_security_group_id  = module.ecs.ecs_security_group_id
  jenkins_sg_id          = module.security.jenkins_sg_id
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password

  depends_on = [module.ecs]
}

resource "local_file" "ansible_inventory" {
  content  = <<EOT
[jenkins_server]
${module.compute.jenkins_public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=./${aws_key_pair.main.key_name}.pem

[app_server]
${module.compute.app_public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=./${aws_key_pair.main.key_name}.pem prometheus_target_ip=${module.compute.app_server_private_ip}

# -------------------------------------------------------
# Monitoring Node  (Ubuntu 24.04 LTS EC2)
# -------------------------------------------------------
[monitoring_server]
${module.compute.monitoring_server_public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=./${aws_key_pair.main.key_name}.pem

[all:vars]
ansible_python_interpreter=/usr/bin/python3
aws_region=${var.aws_region}
app_env=${var.environment}

# -------------------------------------------------------
# Observability versions
# -------------------------------------------------------
prometheus_version=3.9.1
node_exporter_version=1.10.2
EOT
  filename = "${path.module}/../Ansible/inventory.ini"

  depends_on = [local_sensitive_file.private_key_ansible]
}
