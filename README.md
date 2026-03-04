# SpendWise Secure CI/CD Pipeline

### DevSecOps Pipeline with SAST · SCA · Secret Scanning · Image Scanning · SBOM · ECS Fargate Deployment

![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=flat&logo=jenkins&logoColor=white)
![AWS ECS](https://img.shields.io/badge/AWS_ECS-FF9900?style=flat&logo=amazonecs&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![CodeQL](https://img.shields.io/badge/CodeQL-SAST-blue?style=flat)
![Snyk](https://img.shields.io/badge/Snyk-SCA-4C4A73?style=flat&logo=snyk&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-Image_Scan-1904DA?style=flat)
![Gitleaks](https://img.shields.io/badge/Gitleaks-Secret_Scan-red?style=flat)

[Overview](#project-overview) • [Architecture](#architecture) • [Pipeline Stages](#pipeline-stages) • [Security Gates](#security-gates) • [Prerequisites](#prerequisites) • [Setup](#setup) • [Deliverables](#deliverables)

---

## Project Overview

This project implements a **production-grade Secure CI/CD Pipeline** for the SpendWise full-stack web application. Every commit triggers an automated 13-stage Jenkins pipeline that builds, security-scans, and deploys the application to **AWS ECS Fargate** — with hard pipeline blocks on any HIGH or CRITICAL security finding.

### What This Pipeline Delivers

| Capability | Implementation |
|---|---|
| **Secret Detection** | Gitleaks — blocks on any credential/key found in source |
| **Dependency Scanning (SCA)** | Snyk — blocks on HIGH/CRITICAL in production deps |
| **Static Analysis (SAST)** | CodeQL — blocks on HIGH/CRITICAL JavaScript findings |
| **Container Image Scanning** | Trivy — blocks on HIGH/CRITICAL fixable CVEs |
| **Software Bill of Materials** | Syft/CycloneDX JSON for backend and frontend images |
| **Versioned Image Registry** | AWS ECR with `BUILD_NUMBER` + `latest` tags |
| **ECS Fargate Deployment** | Rolling deploy with task definition revision management |
| **Observability** | CloudWatch logs + 7 alarms + Container Insights |
| **Infrastructure as Code** | Modular Terraform (8 modules) |

---

## Architecture

![Architecture Diagram](assets/architecture_digram-Task2.png)
*AWS infrastructure architecture — Jenkins → ECR → ECS Fargate → RDS*

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Jenkins CI/CD Server                          │
│                    (EC2 · Amazon Linux 2023)                         │
│                                                                      │
│  ┌────────┐ ┌──────────┐ ┌─────────┐ ┌────────┐ ┌────────────────┐ │
│  │Gitleaks│ │  Snyk    │ │ CodeQL  │ │ Trivy  │ │  Syft / SBOM   │ │
│  │Secret  │ │  SCA     │ │  SAST   │ │ Image  │ │  CycloneDX     │ │
│  │Scan    │ │ Dep Scan │ │ JS Scan │ │ Scan   │ │  JSON          │ │
│  └────────┘ └──────────┘ └─────────┘ └────────┘ └────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │ Push images + Register task def
                             ▼
┌───────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (eu-central-1)                 │
│                                                                       │
│  ┌──────────────────┐    ┌────────────────────────────────────────┐  │
│  │   Amazon ECR     │    │         AWS ECS Fargate                │  │
│  │                  │    │                                        │  │
│  │  ├─ backend:N    │───▶│  Task Definition (rev N)               │  │
│  │  ├─ backend:lat  │    │  ├─ spendwise-backend  (Node.js/ESM)   │  │
│  │  ├─ frontend:N   │    │  └─ spendwise-frontend (React/Nginx)   │  │
│  │  └─ frontend:lat │    │                                        │  │
│  │  Lifecycle:      │    │  Rolling deploy + Circuit Breaker      │  │
│  │  keep last 5     │    │  CloudWatch Logs (awslogs driver)      │  │
│  └──────────────────┘    └────────────────────────────────────────┘  │
│                                         │                             │
│  ┌──────────────────────────────────────▼───────────────────────┐    │
│  │  AWS SSM Parameter Store                                     │    │
│  │  /monitor-spendwise/dev/db/name · db/user · db/password      │    │
│  │  /monitor-spendwise/dev/app/db_host · app ports · jwt_secret │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌─────────────────────────┐   ┌──────────────────────────────────┐  │
│  │  Amazon RDS (PostgreSQL)│   │  CloudWatch                      │  │
│  │  spendwise database     │   │  Log Group: /ecs/monitor-spend.. │  │
│  └─────────────────────────┘   │  7 Alarms · Container Insights   │  │
│                                └──────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Pipeline Stages

The Jenkinsfile defines **13 stages** that run sequentially. Any security-gate failure immediately blocks and fails the build.

| # | Stage | Tool | Description | Blocks On |
|---|-------|------|-------------|-----------|
| 1 | **Checkout** | Git | Clone SpendWise-Core-App from GitHub; create `security-reports/` dir | — |
| 2 | **Secret Scan** | Gitleaks | Scan repo for hardcoded credentials, API keys, tokens | Any secret found |
| 3 | **Backend Tests** | npm/Jest | Run backend unit test suite in workspace | Test failure |
| 4 | **SCA Scan** | Snyk | Scan production Node.js dependencies for known CVEs | HIGH/CRITICAL CVE |
| 5 | **SAST Scan** | CodeQL | Build JS CodeQL database; run `javascript-security-extended` | ERROR-level finding |
| 6 | **Build Images** | Docker | Build backend and frontend images tagged with `BUILD_NUMBER` + `latest` | Build failure |
| 7 | **Image Scan** | Trivy | Scan both images for fixable HIGH/CRITICAL OS + app CVEs | HIGH/CRITICAL fixable CVE |
| 8 | **Generate SBOM** | Syft | CycloneDX JSON SBOM for both images; archived as artifacts | — |
| 9 | **Push to ECR** | AWS CLI | ECR login; push `BUILD_NUMBER` and `latest` tags for both repos | Push failure |
| 9b | **DB Migration** | psql | Run `init.sql` against RDS via postgres container; idempotent | Migration error |
| 10 | **Deploy to ECS** | AWS CLI + Python | SSM pre-flight · ECR image verify · Register new task def revision · `force-new-deployment` | Pre-flight fail / AWS error |
| 11 | **Verify ECS** | AWS CLI | Poll ECS service until running count reaches desired (8 min timeout) | Service unstable |
| 12 | **Update Prometheus** | Ansible | Re-configure Prometheus `scrape_configs` with new ECS target IP | — |
| 13 | **Cleanup** | Docker | `docker system prune` — remove dangling images and cache | — |

### Pipeline Run Evidence

**Successful Pipeline Build:**

![Jenkins Pipeline Pass 1](<assets/Task 2/Jenkins_Pass1.png>)
*Pipeline stages — all 13 stages green*

![Jenkins Pipeline Pass 2](<assets/Task 2/Jenkins_Pass2.png>)
*Build completion overview*

![Jenkins Pipeline Pass 3](<assets/Task 2/Jenkins_Pass3.png>)
*Stage timing and build details*

**Security Gate Blocking (Pipeline Failure):**

![Jenkins Pipeline Fail 1](<assets/Task 2/Jenkins_Fail1.png>)
*Pipeline blocked — HIGH/CRITICAL vulnerability detected, build aborted*

![Jenkins Pipeline Fail 2](<assets/Task 2/Jenkins_Fail2.png>)
*Failure detail — stage that triggered the security block*

### Stage 10 — ECS Deploy Detail

```
Pre-flight checks
  ├─ Verify 4 SSM parameters exist (db_host, db/name, db/user, db/password)
  └─ Verify ECR images exist at tag BUILD_NUMBER

Render new task definition
  ├─ Fetch current task def JSON from ECS
  ├─ Patch container image tags (backend + frontend → :BUILD_NUMBER)
  ├─ Strip AWS-managed fields (revision, requiresAttributes, etc.)
  └─ Register as new revision → archive as security-reports/task-definition-rendered.json

Update service
  └─ aws ecs update-service --force-new-deployment --task-definition FAMILY:NEW_REVISION

Circuit breaker: if rollout fails, ECS auto-rolls back — Jenkins diagnoses:
  ├─ Stopped task stop reason + exit codes
  ├─ Last 30 CloudWatch log lines from /ecs/monitor-spendwise-dev
  └─ Last 5 ECS service events
```

### ECS Deployment Evidence

**Cluster & Service Overview:**

![ECS Cluster](<assets/Task 2/ECS1.png>)
*ECS cluster with running service and task count*

**Deployment in Progress:**

![ECS Deployment 1](<assets/Task 2/ECS_Deployment1.png>)
*ECS service rolling deployment — new revision being rolled out*

![ECS Deployment 2](<assets/Task 2/ECS_Deployment2.png>)
*Deployment completing — desired task count reached*

![Deployment Status](<assets/Task 2/Deployment?.png>)
*ECS deployment status confirmation*

**Task Definition Revision:**

![Task Definition Revision](<assets/Task 2/Task Definition Revision?.png>)
*New task definition revision registered with updated image tags*

**ECS Service Events:**

![ECS Events Tab](<assets/Task 2/ECS Events Tab.png>)
*ECS service events tab — deployment lifecycle events*

**ECS Log Streams (CloudWatch):**

![ECS Log Streams](<assets/Task 2/ECS_LogStreams.png>)
*CloudWatch log streams for ECS containers*

---

## Security Gates

### How Each Gate Blocks the Pipeline

| Tool | Exit Code Semantics | Block Condition |
|------|--------------------|-----------------------|
| **Gitleaks** | `0` = clean · `1` = secrets found | Any non-zero exit |
| **Snyk** | `0` = clean · `1` = HIGH/CRITICAL · `2` = scan error | Exit 1 or 2 |
| **CodeQL** | SARIF parsed — count of `"level": "error"` results | Count > 0 |
| **Trivy** | `0` = clean · `1` = HIGH/CRITICAL fixable found | Any non-zero exit from either image scan |

All scan reports are archived as build artifacts regardless of pass/fail:

```
security-reports/
├── gitleaks-report.json          # Secret scan — Gitleaks JSON
├── snyk-report.json              # SCA — Snyk JSON
├── snyk-stderr.log               # Snyk progress/error log (split from JSON)
├── codeql-results.sarif          # SAST — CodeQL SARIF
├── trivy-backend-report.json     # Image scan — backend
├── trivy-frontend-report.json    # Image scan — frontend
├── sbom-backend.json             # SBOM — Syft CycloneDX JSON
├── sbom-frontend.json            # SBOM — Syft CycloneDX JSON
└── task-definition-rendered.json # ECS task def registered this build
```

**Archived Build Artifacts in Jenkins:**

![Jenkins Artifacts 1](<assets/Task 2/Jenkins_Artifacts1.png>)
*Security reports archived as build artifacts — accessible per build*

![Jenkins Artifacts 2](<assets/Task 2/Jenkins_Artifacts2.png>)
*Artifact listing showing all scan reports and SBOM files*

### Testing the Security Gates (Assignment Requirement 8)

To verify the Snyk gate blocks on vulnerable dependencies:

```bash
# 1. In SpendWise-Core-App/backend/package.json, add:
"lodash": "4.17.15"

# 2. Run npm install in backend/, commit and push
# 3. Trigger the pipeline — Stage 4 (SCA Scan) will FAIL with:
#    ❌ Snyk found HIGH/CRITICAL vulnerabilities — blocking pipeline
#    [HIGH] SNYK-JS-LODASH-... in lodash@4.17.15

# 4. Remove the vulnerable dep, commit, and push → pipeline passes
```

---

## Infrastructure (Terraform)

The `terraform/` directory uses **8 Terraform modules**:

```
terraform/
├── main.tf               # Root — wires all modules together
├── provider.tf           # AWS provider (eu-central-1)
├── variable.tf           # Input variables
├── output.tf             # Outputs (ECR URLs, cluster name, etc.)
├── dev.tfvars            # Development environment values
└── modules/
    ├── networking/       # VPC, subnets, IGW, route tables
    ├── security/         # Security groups, IAM roles (Jenkins + ECS)
    ├── compute/          # EC2 Jenkins server (t3.medium)
    ├── ecr/              # Two ECR repos + lifecycle policy (keep last 5)
    ├── ecs/              # ECS Fargate cluster + service + task definition
    ├── rds/              # PostgreSQL RDS instance
    ├── parameters/       # SSM Parameter Store (7 parameters)
    └── monitoring/       # CloudWatch log group + 7 alarms + CloudTrail + GuardDuty
```

### ECR Lifecycle Policy

Each repository is configured to:
- Keep the last **5 tagged images**
- Expire **untagged images** after **1 day**

**ECR Repositories:**

![ECR Repositories 1](<assets/Task 2/ECR_Repositories1.png>)
*ECR repositories — backend and frontend image registries*

![ECR Repositories 2](<assets/Task 2/ECR_Repositories2.png>)
*Versioned image tags in ECR (BUILD_NUMBER + latest)*

**Lifecycle Policy Configuration:**

![ECR Lifecycle Policy](<assets/Task 2/ECR Lifecycle Policy.png>)
*ECR lifecycle policy — keep last 5 tagged, expire untagged after 1 day*

### CloudWatch Monitoring

| Alarm | Metric | Threshold |
|-------|--------|-----------|
| High CPU | `ECS/CPUUtilization` | > 80% for 5 min |
| High Memory | `ECS/MemoryUtilization` | > 80% for 5 min |
| Running Tasks | `ECS/RunningTaskCount` | < 1 for 1 min |
| 5xx Errors | App logs (metric filter) | > 10 in 5 min |
| DB CPU | `RDS/CPUUtilization` | > 80% for 5 min |
| DB Connections | `RDS/DatabaseConnections` | > 100 |
| ECS Service Events | CloudTrail | Deployment events |

**CloudWatch Log Groups & Streams:**

![CloudWatch 1](<assets/Task 2/CloudWatch1.png>)
*CloudWatch log group for ECS containers*

![CloudWatch 2](<assets/Task 2/CloudWatch2.png>)
*CloudWatch log streams — one per ECS task*

![CloudWatch 3](<assets/Task 2/CloudWatch3.png>)
*CloudWatch metrics and alarms dashboard*

![CloudWatch 4](<assets/Task 2/CloudWatch4.png>)
*CloudWatch alarm states — ECS CPU, memory, and task count alarms*

![CloudWatch Log Stream Contents](<assets/Task 2/CloudWatch Log Stream Contents.png>)
*Live log stream contents from running ECS container*

---

## Prerequisites

| Requirement | Purpose |
|---|---|
| AWS account (`eu-central-1`) | Cloud infrastructure |
| AWS CLI configured | Terraform + Jenkins AWS operations |
| Terraform >= 1.0 | Infrastructure provisioning |
| Jenkins (EC2, Amazon Linux 2023) | Pipeline execution |
| Docker | Image builds and tool containers |
| CodeQL CLI at `/opt/codeql-cli/codeql/` | SAST scanning (install on Jenkins server) |
| Snyk account + API token | SCA scanning |
| PostgreSQL client (via Docker) | DB migration |

---

## Setup

### 1. Provision Infrastructure

```bash
cd terraform
cp example.tfvars dev.tfvars
# Edit dev.tfvars — set your IP, postgres password, etc.
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

Key outputs after apply:
```
jenkins_public_ip            = "<ip>"
backend_ecr_repository_url   = "605134436600.dkr.ecr.eu-central-1.amazonaws.com/monitor-spendwise-backend"
frontend_ecr_repository_url  = "605134436600.dkr.ecr.eu-central-1.amazonaws.com/monitor-spendwise-frontend"
ecs_cluster_name             = "monitor-spendwise-dev-cluster"
```

### 2. Install CodeQL CLI on Jenkins Server

```bash
ssh ec2-user@<jenkins_ip>
sudo mkdir -p /opt/codeql-cli
cd /opt/codeql-cli
# Download the CodeQL bundle for Linux from:
# https://github.com/github/codeql-action/releases
sudo wget https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.x.x/codeql-bundle-linux64.tar.gz
sudo tar -xzf codeql-bundle-linux64.tar.gz
# Verify:
/opt/codeql-cli/codeql/codeql --version
```

### 3. Configure Jenkins Credentials

Go to **Manage Jenkins → Credentials** and add:

| Credential ID | Type | Contents |
|---|---|---|
| `aws-credentials` | AWS Credentials | AWS Access Key ID + Secret Access Key |
| `aws-account-id` | Secret Text | Your 12-digit AWS Account ID |
| `snyk-token` | Secret Text | Snyk API token (from snyk.io account settings) |

### 4. Create Jenkins Pipeline Job

1. New Item → Pipeline
2. Pipeline → Pipeline script from SCM
3. SCM: Git → `https://github.com/KofiAckah/Secure-CI-CD-Pipeline.git`
4. Script Path: `Jenkinsfile`
5. Save → Build Now

### 5. SSM Parameters

The pipeline reads these parameters at deploy time. Terraform creates them; verify with:

```bash
aws ssm get-parameters-by-path \
  --path "/monitor-spendwise/dev" \
  --recursive \
  --region eu-central-1 \
  --query 'Parameters[*].Name'
```

Expected parameters:
- `/monitor-spendwise/dev/db/name`
- `/monitor-spendwise/dev/db/user`
- `/monitor-spendwise/dev/db/password`
- `/monitor-spendwise/dev/app/db_host`
- `/monitor-spendwise/dev/app/backend_port`
- `/monitor-spendwise/dev/app/db_port`
- `/monitor-spendwise/dev/app/frontend_port`

---

## Repositories

| Repository | URL | Contents |
|---|---|---|
| **Pipeline repo** (this repo) | `https://github.com/KofiAckah/Secure-CI-CD-Pipeline.git` | Jenkinsfile, Terraform, Ansible |
| **Application repo** | `https://github.com/KofiAckah/SpendWise-Core-App.git` | Node.js backend, React frontend, Dockerfiles |

---

## Deliverables Checklist

All 9 assignment requirements are met:

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | App from previous project with tests + Dockerfile; images stored in ECR | ✅ | Stages 3, 6, 9 — ECR repos in `terraform/ecr/` |
| 2 | SAST (CodeQL), SCA (Snyk), image scan (Trivy), secret scan (Gitleaks), SBOM (Syft/CycloneDX) | ✅ | Stages 2, 4, 5, 7, 8 |
| 3 | Pipeline fails on HIGH/CRITICAL vulns or secrets; all reports archived | ✅ | Security gate logic in each scan stage; `archiveArtifacts` in `post.always` |
| 4 | Build and push versioned image tags (`BUILD_NUMBER` + `latest`) to ECR | ✅ | Stage 9 — `docker push :${IMAGE_TAG}` + `:latest` |
| 5 | Render and register new ECS task definition revision with new image tag | ✅ | Stage 10 — Python patching + `aws ecs register-task-definition` |
| 6 | Update ECS service with rolling deploy + force-new-deployment | ✅ | Stage 10 — `aws ecs update-service --force-new-deployment` with circuit breaker |
| 7 | CloudWatch logs via `awslogs` driver; alarms; custom deployment metrics | ✅ | `awslogs` in task def · `terraform/monitoring/` · Stage 11 verify |
| 8 | Manual test: inject `lodash@4.17.15` → Snyk blocks; remove → passes | ⚠️ | See [Testing the Security Gates](#testing-the-security-gates-assignment-requirement-8) |
| 9 | ECR lifecycle policy + ECS task definition revision cleanup (keep last 3) | ✅ | `terraform/ecr/main.tf` lifecycle rules · Stage 10 deregisters old revisions |

### Build Artifacts (per build)

Each successful (or failed-at-scan) build archives:

```
security-reports/
├── gitleaks-report.json
├── snyk-report.json
├── snyk-stderr.log
├── codeql-results.sarif
├── trivy-backend-report.json
├── trivy-frontend-report.json
├── sbom-backend.json              ← CycloneDX JSON
├── sbom-frontend.json             ← CycloneDX JSON
└── task-definition-rendered.json  ← ECS task def registered this build
```

---

## Project Structure

```
SpendWise-Ops-Monitor/
├── Jenkinsfile                        # 13-stage secure CI/CD pipeline
├── JENKINS_SETUP.md                   # Jenkins server setup guide
├── README.md                          # This file
├── README-monitoring.md               # Previous project (Prometheus/Grafana observability)
│
├── terraform/                         # Infrastructure as Code (8 modules)
│   ├── main.tf
│   ├── provider.tf
│   ├── variable.tf
│   ├── output.tf
│   ├── dev.tfvars
│   ├── example.tfvars
│   ├── networking/                    # VPC, subnets, routing
│   ├── security/                      # IAM roles, security groups
│   ├── compute/                       # Jenkins EC2 instance
│   ├── ecr/                           # ECR repos + lifecycle policy
│   ├── ecs/                           # ECS cluster, service, task definition
│   ├── rds/                           # PostgreSQL RDS
│   ├── parameters/                    # SSM Parameter Store
│   └── monitoring/                    # CloudWatch alarms, CloudTrail, GuardDuty
│
└── Ansible/                           # Server configuration
    ├── ansible.cfg
    ├── inventory.ini
    └── playbooks/
        ├── jenkins.yml
        ├── app.yml
        ├── monitoring.yml
        └── templates/
            ├── prometheus.yml.j2
            ├── alert_rules.yml.j2
            └── ...
```

---

## Environment Variables (Jenkins Pipeline)

```groovy
AWS_REGION        = 'eu-central-1'
PROJECT_NAME      = 'monitor-spendwise'
ENVIRONMENT       = 'dev'
IMAGE_TAG         = "${env.BUILD_NUMBER}"      // increments per build
ECS_CLUSTER       = 'monitor-spendwise-dev-cluster'
ECS_SERVICE       = 'monitor-spendwise-dev-service'
TASK_FAMILY       = 'monitor-spendwise-dev-task'
BACKEND_ECR_REPO  = '<account>.dkr.ecr.eu-central-1.amazonaws.com/monitor-spendwise-backend'
FRONTEND_ECR_REPO = '<account>.dkr.ecr.eu-central-1.amazonaws.com/monitor-spendwise-frontend'
REPORTS_DIR       = 'security-reports'
```

---

## Troubleshooting

### ECS Task Fails to Start

Stage 10 automatically diagnoses failures. Common causes:

| Error | Cause | Fix |
|---|---|---|
| `ResourceInitializationError` | SSM parameter missing or wrong path | Check SSM parameter names match `/monitor-spendwise/dev/...` |
| `CannotPullContainerError` | ECR image tag not found | Verify Stage 9 (Push to ECR) completed successfully |
| `SyntaxError: Cannot use import statement` | `package.json` missing from Docker image | Ensure `COPY package.json .` is in `backend/Dockerfile` |
| ECS service stuck in 0/1 running | Container exits immediately | Check CloudWatch logs at `/ecs/monitor-spendwise-dev` |

### Snyk Authentication Fails

```bash
# Verify token is valid
snyk auth <token>
# Re-add credential in Jenkins:
# Manage Jenkins → Credentials → snyk-token
```

### CodeQL Database Creation Fails

```bash
# Check CodeQL CLI is at the expected path
/opt/codeql-cli/codeql/codeql --version
# Ensure the Jenkins user has read access to source files
ls -la /var/lib/jenkins/workspace/<job-name>/SpendWise-Core-App/backend
```
