# Jenkins Setup Guide — SpendWise CI/CD Pipeline

This guide walks you through configuring Jenkins after Ansible has provisioned the server.  
By the end you will have a working pipeline that:  
1. Runs backend tests on every push  
2. Builds and pushes Docker images to AWS ECR  
3. Deploys automatically to the App Server  

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1 — Access Jenkins](#step-1--access-jenkins)
- [Step 2 — Complete the Setup Wizard](#step-2--complete-the-setup-wizard)
- [Step 3 — Install Additional Plugins](#step-3--install-additional-plugins)
- [Step 4 — Configure Credentials](#step-4--configure-credentials)
- [Step 5 — Install Node.js on Jenkins Server](#step-5--install-nodejs-on-jenkins-server)
- [Step 6 — Create the Pipeline Job](#step-6--create-the-pipeline-job)
- [Step 7 — Run the Pipeline](#step-7--run-the-pipeline)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, make sure you have:

- ✅ Terraform applied (`terraform apply -var-file=dev.tfvars`)
- ✅ Ansible Jenkins playbook run (`ansible-playbook playbooks/jenkins.yml`)
- ✅ Ansible App playbook run (`ansible-playbook playbooks/app.yml`)
- ✅ `SpendWise-KP.pem` key available in the `Ansible/` directory
- ✅ Your AWS Account ID (run: `aws sts get-caller-identity --query Account --output text`)

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
| **Description** | EC2 SSH Key for App Server |
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

### C. Verify Both Credentials Exist

After adding both, your credentials list should show:

```
aws-account-id   [Secret text]
ec2-ssh-key      [SSH Username with private key]
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

| Stage | What It Does |
|-------|-------------|
| ✅ **Checkout** | Clones `SpendWise-Core-App` into workspace |
| ✅ **Get App Server IP** | Queries AWS for the app server's private & public IPs |
| ✅ **Run Backend Tests** | Runs `npm test` inside `backend/` |
| ✅ **Build Docker Images** | Builds `backend` and `frontend` images with build tag |
| ✅ **Push to ECR** | Authenticates with ECR and pushes both images |
| ✅ **Deploy to App Server** | SSHs to app server, pulls images, restarts with new compose override |
| ✅ **Verify Deployment** | Runs `docker ps` and hits `/api/health` endpoint |
| ✅ **Cleanup Old Images** | Keeps last 3 builds on Jenkins server |

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

**Solution:** Install Node.js (see [Step 5](#step-5--install-nodejs-on-jenkins-server)).

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

**Symptom:** `Could not find running App Server with tag: monitor-spendwise-dev-app-server`

**Solution:** The App Server EC2 instance may be stopped:

```bash
cd terraform
terraform output app_instance_id
# Then: aws ec2 start-instances --instance-ids <id> --region eu-central-1
```

Or re-run `terraform apply -var-file=dev.tfvars` to ensure all instances are running.

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
