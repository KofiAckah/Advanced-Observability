#!/usr/bin/env bash
# Stage 10 — Deploy to ECS Fargate
set -euo pipefail

echo '=== Deploying to ECS Fargate ==='

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
    --repository-name monitor-spendwise-backend \
    --image-ids imageTag="${IMAGE_TAG}" \
    --region "${AWS_REGION}" > /dev/null
echo "  ✅ backend:${IMAGE_TAG}"

aws ecr describe-images \
    --repository-name monitor-spendwise-frontend \
    --image-ids imageTag="${IMAGE_TAG}" \
    --region "${AWS_REGION}" > /dev/null
echo "  ✅ frontend:${IMAGE_TAG}"

# ── Fetch and patch task definition ────────────────────────────
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

# Strip AWS-managed fields that are rejected on re-register
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

# ── Register new task definition revision ──────────────────────
echo "--- Registering new task definition revision ---"
NEW_REVISION=$(aws ecs register-task-definition \
    --region "${AWS_REGION}" \
    --cli-input-json file://new-task-def.json \
    --query 'taskDefinition.revision' \
    --output text)
echo "Registered revision: $NEW_REVISION"

# ── Update ECS service ─────────────────────────────────────────
echo "--- Updating ECS service ---"
aws ecs update-service \
    --region "${AWS_REGION}" \
    --cluster "${ECS_CLUSTER}" \
    --service "${ECS_SERVICE}" \
    --task-definition "${TASK_FAMILY}:${NEW_REVISION}" \
    --force-new-deployment

cp new-task-def.json "${REPORTS_DIR}/task-definition-rendered.json"
echo "✅ ECS service updated to revision $NEW_REVISION"
