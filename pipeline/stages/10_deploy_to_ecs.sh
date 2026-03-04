#!/usr/bin/env bash
# Stage 10 — Blue/Green Deploy via AWS CodeDeploy
# 1. Pre-flight: verify SSM parameters and ECR images exist.
# 2. Fetch current ECS task definition, patch image tags, register new revision.
# 3. Build and upload appspec.yml to S3.
# 4. Create a CodeDeploy deployment (blue/green via ALB listener shift).
# 5. Save the deployment ID so Stage 11 can poll for completion.
set -euo pipefail

echo '=== Blue/Green Deploy via AWS CodeDeploy ==='

# ── Pre-flight 1: verify all SSM parameters exist ──────────────
echo "--- Pre-flight: verifying SSM parameters ---"
MISSING=0
for param in \
    "/${PROJECT_NAME}/${ENVIRONMENT}/app/db_host" \
    "/${PROJECT_NAME}/${ENVIRONMENT}/db/name" \
    "/${PROJECT_NAME}/${ENVIRONMENT}/db/user" \
    "/${PROJECT_NAME}/${ENVIRONMENT}/db/password"; do
    set +e
    aws ssm get-parameter --name "$param" \
        --region "${AWS_REGION}" \
        --query 'Parameter.Name' \
        --output text > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "  ❌ MISSING: $param"
        MISSING=$((MISSING + 1))
    else
        echo "  ✅ $param"
    fi
    set -e
done
if [ "$MISSING" -gt 0 ]; then
    echo "❌ $MISSING SSM parameter(s) missing — ECS will fail ResourceInitializationError"
    exit 1
fi

# ── Pre-flight 2: verify ECR images exist at this tag ──────────
echo "--- Pre-flight: verifying ECR images (tag: ${IMAGE_TAG}) ---"
aws ecr describe-images \
    --repository-name advanced-monitor-spendwise-backend \
    --image-ids imageTag="${IMAGE_TAG}" \
    --region "${AWS_REGION}" > /dev/null
echo "  ✅ backend:${IMAGE_TAG}"

aws ecr describe-images \
    --repository-name advanced-monitor-spendwise-frontend \
    --image-ids imageTag="${IMAGE_TAG}" \
    --region "${AWS_REGION}" > /dev/null
echo "  ✅ frontend:${IMAGE_TAG}"

# ── Pre-flight 3: read CodeDeploy config from SSM ─────────────
echo "--- Reading CodeDeploy config from SSM ---"
APPSPEC_BUCKET=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/${ENVIRONMENT}/codedeploy/s3_bucket" \
    --region "${AWS_REGION}" \
    --query 'Parameter.Value' \
    --output text)
echo "  AppSpec S3 bucket : $APPSPEC_BUCKET"

CODEDEPLOY_APP=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/${ENVIRONMENT}/codedeploy/app_name" \
    --region "${AWS_REGION}" \
    --query 'Parameter.Value' \
    --output text)
echo "  CodeDeploy app    : $CODEDEPLOY_APP"

CODEDEPLOY_DG=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/${ENVIRONMENT}/codedeploy/deployment_group" \
    --region "${AWS_REGION}" \
    --query 'Parameter.Value' \
    --output text)
echo "  Deployment group  : $CODEDEPLOY_DG"

# ── Fetch and patch task definition ───────────────────────────
echo "--- Fetching current task definition ---"
aws ecs describe-task-definition \
    --task-definition "${TASK_FAMILY}" \
    --region "${AWS_REGION}" \
    --query 'taskDefinition' \
    --output json > current-task-def.json

echo "--- Updating image tags in task definition ---"
python3 - <<PYEOF
import json, os

with open('current-task-def.json') as f:
    td = json.load(f)

backend_repo  = os.environ['BACKEND_ECR_REPO']
frontend_repo = os.environ['FRONTEND_ECR_REPO']
image_tag     = os.environ['IMAGE_TAG']

for container in td['containerDefinitions']:
    if container['name'] == 'spendwise-backend':
        container['image'] = f'{backend_repo}:{image_tag}'
    if container['name'] == 'spendwise-frontend':
        container['image'] = f'{frontend_repo}:{image_tag}'

# Strip AWS-managed fields that cannot be re-registered
for key in [
    'taskDefinitionArn', 'revision', 'status',
    'requiresAttributes', 'compatibilities',
    'registeredAt', 'registeredBy',
    'deregisteredAt', 'enableFaultInjection',
]:
    td.pop(key, None)

with open('new-task-def.json', 'w') as f:
    json.dump(td, f, indent=2)

be = next((c['image'] for c in td['containerDefinitions'] if c['name']=='spendwise-backend'), 'NOT FOUND')
fe = next((c['image'] for c in td['containerDefinitions'] if c['name']=='spendwise-frontend'), 'NOT FOUND')
print('Task definition updated:')
print('  backend  -> ' + be)
print('  frontend -> ' + fe)
PYEOF

# ── Register new task definition revision ─────────────────────
echo "--- Registering new task definition revision ---"
REGISTER_JSON=$(aws ecs register-task-definition \
    --region "${AWS_REGION}" \
    --cli-input-json file://new-task-def.json \
    --output json)

NEW_REVISION=$(echo "$REGISTER_JSON" | python3 -c \
    "import json,sys; print(json.load(sys.stdin)['taskDefinition']['revision'])")
NEW_TASK_DEF_ARN=$(echo "$REGISTER_JSON" | python3 -c \
    "import json,sys; print(json.load(sys.stdin)['taskDefinition']['taskDefinitionArn'])")

echo "  Registered revision : $NEW_REVISION"
echo "  Task definition ARN : $NEW_TASK_DEF_ARN"

cp new-task-def.json "${REPORTS_DIR}/task-definition-rendered.json"

# ── Build and upload appspec.yml ───────────────────────────────
echo "--- Rendering appspec.yml ---"

# Determine the subnet IDs the ECS tasks will use (read from the running service)
SUBNET_IDS=$(aws ecs describe-services \
    --region "${AWS_REGION}" \
    --cluster "${ECS_CLUSTER}" \
    --services "${ECS_SERVICE}" \
    --query 'services[0].networkConfiguration.awsvpcConfiguration.subnets' \
    --output json | python3 -c "import json,sys; print(','.join(json.load(sys.stdin)))")

SG_IDS=$(aws ecs describe-services \
    --region "${AWS_REGION}" \
    --cluster "${ECS_CLUSTER}" \
    --services "${ECS_SERVICE}" \
    --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups' \
    --output json | python3 -c "import json,sys; print(','.join(json.load(sys.stdin)))")

cat > appspec-rendered.yml <<APPSPEC
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "${NEW_TASK_DEF_ARN}"
        LoadBalancerInfo:
          ContainerName: "spendwise-backend"
          ContainerPort: 5000
        PlatformVersion: LATEST
        NetworkConfiguration:
          AwsvpcConfiguration:
            Subnets:
$(echo "$SUBNET_IDS" | tr ',' '\n' | sed 's/^/              - /')
            SecurityGroups:
$(echo "$SG_IDS" | tr ',' '\n' | sed 's/^/              - /')
            AssignPublicIp: ENABLED
APPSPEC

echo "--- AppSpec contents ---"
cat appspec-rendered.yml

# Upload appspec to S3 (versioned key per build so logs show history)
APPSPEC_S3_KEY="${TASK_FAMILY}/${IMAGE_TAG}/appspec.yml"
aws s3 cp appspec-rendered.yml "s3://${APPSPEC_BUCKET}/${APPSPEC_S3_KEY}" \
    --region "${AWS_REGION}"
echo "✅ Uploaded to s3://${APPSPEC_BUCKET}/${APPSPEC_S3_KEY}"

# ── Create CodeDeploy deployment ───────────────────────────────
echo "--- Creating CodeDeploy blue/green deployment ---"
DEPLOYMENT_ID=$(aws deploy create-deployment \
    --region "${AWS_REGION}" \
    --application-name "${CODEDEPLOY_APP}" \
    --deployment-group-name "${CODEDEPLOY_DG}" \
    --revision "revisionType=S3,s3Location={bucket=${APPSPEC_BUCKET},key=${APPSPEC_S3_KEY},bundleType=YAML}" \
    --description "Jenkins build ${IMAGE_TAG} — task def revision ${NEW_REVISION}" \
    --query 'deploymentId' \
    --output text)

echo "✅ CodeDeploy deployment created: ${DEPLOYMENT_ID}"
echo "   Application : ${CODEDEPLOY_APP}"
echo "   Group       : ${CODEDEPLOY_DG}"
echo "   Task def    : ${TASK_FAMILY}:${NEW_REVISION}"
echo "   AppSpec key : ${APPSPEC_S3_KEY}"

# Save deployment ID for Stage 11
echo "${DEPLOYMENT_ID}" > /tmp/codedeploy_deployment_id.txt
echo "${DEPLOYMENT_ID}" > "${REPORTS_DIR}/codedeploy_deployment_id.txt"
