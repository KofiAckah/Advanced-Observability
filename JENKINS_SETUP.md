# Jenkins Setup Guide — Advanced SpendWise CI/CD Pipeline

This guide walks you through configuring Jenkins after Ansible has provisioned the server.  
By the end you will have a working pipeline that:
1. Runs backend tests on every push
2. Scans secrets (Gitleaks), dependencies (Snyk), code (CodeQL), images (Trivy), and generates an SBOM (Syft)
3. Builds and pushes Docker images to AWS ECR
4. Runs DB migrations and deploys to ECS Fargate
5. Updates Prometheus ECS scrape targets after every deploy

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Step 0 — Provision Jenkins Server with Ansible](#step-0--provision-jenkins-server-with-ansible)
- [Step 1 — Access Jenkins](#step-1--access-jenkins)
- [Step 2 — Complete the Setup Wizard](#step-2--complete-the-setup-wizard)
- [Step 3 — Install Additional Plugins](#step-3--install-additional-plugins)
- [Step 4 — Configure Credentials](#step-4--configure-credentials)
- [Step 5 — Create the Pipeline Job](#step-5--create-the-pipeline-job)
- [Step 6 — Run the Pipeline](#step-6--run-the-pipeline)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, make sure you have:

- ✅ Terraform applied (`terraform apply -var-file=dev.tfvars`)
- ✅ `SpendWise-KP.pem` key available in the `Ansible/` directory
- ✅ Your AWS Account ID (run: `aws sts get-caller-identity --query Account --output text`)
- ✅ A Snyk account and API token from [app.snyk.io/account](https://app.snyk.io/account)

---

## Step 0 — Provision Jenkins Server with Ansible

Run the Jenkins playbook **before** accessing the UI. It installs and configures:

| Tool | Version / Notes |
|------|-----------------|
| **Jenkins** | Latest stable RPM |
| **Java 17** | Amazon Corretto |
| **Docker + Compose + Buildx** | Latest |
| **Node.js + npm** | Latest via dnf |
| **Git** | Latest |
| **CodeQL CLI** | Bundle v2.17.6 (at `/opt/codeql-cli/codeql/codeql`) |

```bash
cd Ansible
ansible-playbook playbooks/jenkins.yml
```

Also run the app playbook to install Node Exporter on the App Server:

```bash
ansible-playbook playbooks/app.yml
```

> **Note:** Trivy, Syft, and Gitleaks run via Docker inside the pipeline — no manual installation needed.

---

## Step 1 — Access Jenkins

### 1.1 Get the Jenkins URL

```bash
cd terraform
terraform output jenkins_public_ip
# Example output: 18.184.72.91
```

Open your browser: `http://<jenkins_public_ip>:8080`

### 1.2 Get the Initial Admin Password

```bash
# Get the Jenkins IP from Terraform output
JENKINS_IP=$(terraform output -raw jenkins_public_ip)

# SSH in and retrieve the password
ssh -i ../Ansible/SpendWise-KP.pem ec2-user@$JENKINS_IP \
  "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
```

Paste this password into the Jenkins unlock screen.

---

## Step 2 — Complete the Setup Wizard

1. Paste the initial admin password
2. Click **"Install suggested plugins"** — wait for installation to finish
3. Create your admin user (fill in username, password, full name, email)
4. Set the Jenkins URL — leave the default value as-is
5. Click **"Start using Jenkins"**

---

## Step 3 — Install Additional Plugins

Go to **Manage Jenkins → Plugins → Available plugins**

Search and install each of the following:

| Plugin | Why It's Needed |
|--------|-----------------|
| **Docker Pipeline** | Enables Docker commands inside pipeline stages |
| **SSH Agent** | Allows `sshagent([...])` to inject SSH keys securely |
| **AWS Credentials** | Stores AWS secrets safely in Jenkins |
| **Credentials Binding** | Injects secrets via `withCredentials([string(...)])` — required for Snyk token |

After installing, tick **"Restart Jenkins when installation is complete"**.

---

## Step 4 — Configure Credentials

Navigate to:  
**Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials**

### A. Add AWS Account ID

| Field | Value |
|-------|-------|
| **Kind** | Secret text |
| **Secret** | Your 12-digit AWS Account ID |
| **ID** | `aws-account-id` |
| **Description** | AWS Account ID for ECR |

> Get your Account ID: `aws sts get-caller-identity --query Account --output text`

Click **Create**.

---

### B. Add SSH Key for App Server

| Field | Value |
|-------|-------|
| **Kind** | SSH Username with private key |
| **ID** | `ec2-ssh-key` |
| **Description** | EC2 SSH Key for App Server and Monitoring Server |
| **Username** | `ec2-user` |
| **Private Key** | Select **"Enter directly"** → click **Add** |

Paste the full contents of your `SpendWise-KP.pem` file:

```bash
# On your local machine, print the key content:
cat Ansible/SpendWise-KP.pem
```

Copy everything from `-----BEGIN RSA PRIVATE KEY-----` to `-----END RSA PRIVATE KEY-----` (inclusive) and paste it.

Click **Create**.

---

### C. Add Snyk API Token

The pipeline uses Snyk in **Stage 4 (SCA Scan)** to detect HIGH/CRITICAL vulnerabilities in backend dependencies.

> Get your token from: **[app.snyk.io → Account Settings → Auth Token](https://app.snyk.io/account)**

| Field | Value |
|-------|-------|
| **Kind** | Secret text |
| **Secret** | Your Snyk API token (40-character hex string) |
| **ID** | `snyk-token` |
| **Description** | Snyk API token for SCA dependency scanning |

Click **Create**.

---

### D. Verify All Credentials Exist

After adding all credentials, your list should show:

```
aws-account-id   [Secret text]
ec2-ssh-key      [SSH Username with private key]
snyk-token       [Secret text]
```

---

## Step 5 — Create the Pipeline Job

### 5.1 Create a New Pipeline

1. From the Jenkins Dashboard click **"New Item"**
2. Enter name: `spendwise-cicd-pipeline`
3. Select **Pipeline**
4. Click **OK**

### 5.2 Configure the Pipeline

**General tab:**
- ☑ **GitHub project**
- **Project url:** `https://github.com/KofiAckah/SpendWise_Monitoring/`

**Build Triggers tab:**
- ☑ **Poll SCM**
- **Schedule:** `H/5 * * * *`  *(checks for new commits every 5 minutes)*

**Pipeline tab:**
- **Definition:** `Pipeline script from SCM`
- **SCM:** `Git`
- **Repository URL:** `https://github.com/KofiAckah/SpendWise_Monitoring.git`
- **Credentials:** None *(public repository)*
- **Branch Specifier:** `*/main`
- **Script Path:** `Jenkinsfile`

Click **Save**.

---

## Step 6 — Run the Pipeline

1. From the pipeline page click **"Build Now"**
2. Click the build number that appears under **Build History**
3. Click **"Console Output"** to watch live logs

### Expected Stages

| Stage | Tool | What It Does |
|-------|------|--------------|
| ✅ **Checkout** | Git | Clones `SpendWise-Core-App` source code |
| ✅ **Secret Scan** | Gitleaks (Docker) | Blocks pipeline if hardcoded secrets found |
| ✅ **Run Backend Tests** | npm test | Runs unit tests inside `backend/` |
| ✅ **SCA Scan** | Snyk | Scans dependencies for HIGH/CRITICAL CVEs |
| ✅ **SAST Scan** | CodeQL | Static analysis on backend JavaScript code |
| ✅ **Build Docker Images** | Docker Buildx | Builds `backend` and `frontend` images |
| ✅ **Image Scan** | Trivy (Docker) | Scans built images for vulnerabilities |
| ✅ **Generate SBOM** | Syft (Docker) | Creates CycloneDX SBOM for both images |
| ✅ **Push to ECR** | AWS CLI | Authenticates and pushes both images |
| ✅ **DB Migration** | ECS task | Runs Alembic/Prisma migrations against RDS |
| ✅ **Deploy to ECS** | AWS CLI | Registers new task definition and updates service |
| ✅ **Verify ECS Deployment** | AWS CLI | Polls until tasks are stable (8 min timeout) |
| ✅ **Update Prometheus Target** | SSH | Rewrites `ecs_targets.json` on monitoring server |
| ✅ **Cleanup Old Images** | Docker | Prunes dangling images on Jenkins server |

### Security Reports

All scan reports are archived as build artefacts:

| Artefact | Stage |
|----------|-------|
| `security-reports/gitleaks-report.json` | Secret Scan |
| `security-reports/snyk-report.json` | SCA Scan |
| `security-reports/codeql-results.sarif` | SAST Scan |
| `security-reports/trivy-backend-report.json` | Image Scan |
| `security-reports/trivy-frontend-report.json` | Image Scan |
| `security-reports/sbom-backend.json` | SBOM |
| `security-reports/sbom-frontend.json` | SBOM |
| `security-reports/task-definition-rendered.json` | ECS Deploy |

### Accessing the Deployed App

After a successful pipeline run:

```bash
# From terraform directory
APP_IP=$(terraform output -raw app_public_ip)

echo "Frontend : http://$APP_IP"
echo "Backend  : http://$APP_IP:5000/api/health"
```

---

## Troubleshooting

### Issue 1: SSH Connection Refused (Deploy Stage)

**Symptom:** `ssh: connect to host 10.0.1.x port 22: Connection refused`

**Solution:** The Jenkins server and App server are in the same VPC. Check the security group allows port 22 from the Jenkins server's security group.

```bash
# From terraform directory — verify the rule exists
terraform output app_sg_id
# Then check in AWS Console → EC2 → Security Groups → find monitor-spendwise-dev-app-sg
# Inbound should include: SSH (22) from the Jenkins SG
```

---

### Issue 2: `aws-account-id` Credential Not Found

**Symptom:** `CredentialNotFoundException: Could not find credentials with id 'aws-account-id'`

**Solution:** Re-check the credential ID under **Manage Jenkins → Credentials**. The ID must be exactly `aws-account-id` (case-sensitive).

---

### Issue 3: `docker: command not found` on Jenkins

**Symptom:** Pipeline fails at Build stage with `docker: command not found`

**Solution:**

```bash
JENKINS_IP=$(cd terraform && terraform output -raw jenkins_public_ip)
ssh -i Ansible/SpendWise-KP.pem ec2-user@$JENKINS_IP

# Verify jenkins user is in docker group
sudo groups jenkins
# Should include: docker

# If not, add and restart
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

---

### Issue 4: `npm: command not found` on Jenkins

**Symptom:** Run Backend Tests stage fails with `npm: command not found`

**Solution:** Re-run the Ansible Jenkins playbook — it installs Node.js and npm via dnf:

```bash
cd Ansible
ansible-playbook playbooks/jenkins.yml
```

---

### Issue 5: ECR Push Fails (`denied: Your authorization token has expired`)

**Symptom:** Push to ECR fails with auth error

**Solution:** The Jenkins server uses an IAM Instance Role — no credentials needed. Verify the role is attached:

```bash
# SSH to Jenkins server
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/
# Should return the role name (e.g. monitor-spendwise-jenkins-role)
```

If empty, re-run `terraform apply` — the EC2 instance profile may not have been attached.

---

### Issue 6: App Server IP Returns `None`

**Symptom:** `Could not find running App Server with tag: advanced-monitor-spendwise-dev-app-server`

**Solution:** The App Server EC2 instance may be stopped:

```bash
cd terraform
terraform output app_instance_id
# Then: aws ec2 start-instances --instance-ids <id> --region eu-west-1
```

Or re-run `terraform apply -var-file=dev.tfvars` to ensure all instances are running.

---

### Issue 7: `snyk-token` Credential Not Found

**Symptom:** `CredentialNotFoundException: Could not find credentials with id 'snyk-token'`

**Solution:** Add the Snyk token in Jenkins (see [Step 4C](#c-add-snyk-api-token)).

Get your token from: [app.snyk.io → Account Settings → Auth Token](https://app.snyk.io/account)

---

### Issue 8: CodeQL Fails (`/opt/codeql-cli/codeql/codeql: No such file or directory`)

**Symptom:** Stage 5 (SAST Scan) fails with file not found.

**Solution:** Re-run the Ansible Jenkins playbook — it downloads and installs the CodeQL bundle:

```bash
cd Ansible
ansible-playbook playbooks/jenkins.yml
```

Verify installation:

```bash
JENKINS_IP=$(cd terraform && terraform output -raw jenkins_public_ip)
ssh -i Ansible/SpendWise-KP.pem ec2-user@$JENKINS_IP \
  "codeql --version"
```

---

### Issue 9: Snyk Scan Error (`exit code 2`)

**Symptom:** Stage 4 fails with `Snyk scan error — check token validity and network access`

**Solution:**
1. Verify the token is valid at [app.snyk.io/account](https://app.snyk.io/account)
2. Check the Jenkins server has internet access (it needs to reach `snyk.io`)
3. Inspect the report: `security-reports/snyk-report.json` in build artefacts

---

### Debugging Tips

1. **Check Console Output** — Most errors are fully described there
2. **SSH into Jenkins and test commands manually** — Copy the failing command from the logs and run it as the `ec2-user`
3. **Check IAM Role permissions** — The Jenkins instance role must have ECR, EC2 describe, and SSM read permissions (already configured by Terraform)
4. **Verify Docker is running** — `sudo systemctl status docker` on both servers

---

## Architecture Summary

```
┌──────────────┐    webhook/poll    ┌──────────────┐    SSH (private IP)    ┌─────────────┐
│    GitHub    │ ─────────────────▶ │   Jenkins    │ ─────────────────────▶ │  App Server │
│  (ops repo)  │                    │   Server     │                         │  (Docker)   │
└──────────────┘                    └──────┬───────┘                         └──────┬──────┘
                                           │                                         │
                                           │ push images                             │ pull images
                                           ▼                                         ▼
                                    ┌──────────────┐                         ┌──────────────┐
                                    │   AWS ECR    │                         │   AWS ECR    │
                                    │  (backend)   │                         │  (frontend)  │
                                    └──────────────┘                         └──────────────┘
```

**IAM Roles (no static credentials):**
- Jenkins server → ECR push, EC2 describe, SSM read
- App server → ECR pull, SSM read
