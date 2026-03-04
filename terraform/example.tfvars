# --- General Config ---
aws_region   = "eu-central-1"
project_name = "monitor-spendwise"
environment  = "dev"

# --- Networking ---
vpc_cidr           = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"

# --- Security ---
# Replace with your actual IP (e.g., "YOUR.IP.ADDRESS.HERE/32") for better security
# Run: curl ifconfig.me
ssh_allowed_ip = "0.0.0.0/0"

# --- Compute ---
# Jenkins needs more RAM, so we use t3.medium. App is fine on t3.micro.
jenkins_instance_type = "t3.medium"
app_instance_type     = "t3.micro"
key_name              = "AutoKeyPair" # MAKE SURE YOU CREATE THIS IN AWS CONSOLE FIRST

# --- Application Config ---
postgres_db       = "spendwise"
postgres_user     = "spendwise_dev"
postgres_password = "CHANGE_ME_STRONG_PASSWORD"

backend_port         = "5000"
db_host              = "postgres"
db_port              = "5432"
compose_project_name = "spendwise"
frontend_port        = "5173"

# --- Tags ---
common_tags = {
  Project     = "SpendWise"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Owner       = "DevOps Team"
}
