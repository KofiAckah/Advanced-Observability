#!/usr/bin/env bash
# Stage 12 — Update Prometheus ECS Scrape Target
# Requires: MONITORING_KEY / MONITORING_USER from Jenkins withCredentials block
#
# BUG FIX: ECS Fargate task private IP lives in task.attachments (ENI attachment),
# NOT in container.networkInterfaces which is always empty for Fargate.
# Correct JMESPath: attachments[0].details[?name=='privateIPv4Address'].value | [0]
set -euo pipefail

echo '=== Updating Prometheus ECS scrape target ==='

# --- Discover the running ECS task ARN ---
TASK_ARN=$(aws ecs list-tasks \
    --region "${AWS_REGION}" \
    --cluster "${ECS_CLUSTER}" \
    --query 'taskArns[0]' \
    --no-cli-pager \
    --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo "❌ No running ECS tasks found in cluster ${ECS_CLUSTER}"
    exit 1
fi

echo "Task ARN: $TASK_ARN"

# --- Get private IP from the ENI attachment (correct path for Fargate) ---
# ECS Fargate attaches an ENI to the task; the IP is in:
#   task.attachments[type=='ElasticNetworkInterface'].details[name=='privateIPv4Address'].value
ECS_IP=$(aws ecs describe-tasks \
    --region "${AWS_REGION}" \
    --cluster "${ECS_CLUSTER}" \
    --tasks "${TASK_ARN}" \
    --no-cli-pager \
    --query "tasks[0].attachments[0].details[?name=='privateIPv4Address'].value | [0]" \
    --output text)

if [ -z "$ECS_IP" ] || [ "$ECS_IP" = "None" ] || [ "$ECS_IP" = "null" ]; then
    echo "❌ Could not determine ECS task private IP — describe-tasks output:"
    aws ecs describe-tasks \
        --region "${AWS_REGION}" \
        --cluster "${ECS_CLUSTER}" \
        --tasks "${TASK_ARN}" \
        --no-cli-pager \
        --query 'tasks[0].attachments' \
        --output json
    exit 1
fi

echo "ECS backend private IP: ${ECS_IP}"

# --- Write new ecs_targets.json on the monitoring server ---
# Prometheus file_sd_configs auto-reloads this file every 30 s.
# No Prometheus restart needed.
TARGETS_JSON=$(printf '[{"targets":["%s:5000"],"labels":{"service":"spendwise-backend","environment":"dev"}}]' "${ECS_IP}")

ssh -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    -i "${MONITORING_KEY}" \
    ubuntu@52.57.3.18 \
    "echo '${TARGETS_JSON}' | sudo tee /etc/prometheus/ecs_targets.json > /dev/null && echo '✅ ecs_targets.json updated'"

echo "✅ Prometheus will scrape ${ECS_IP}:5000 within 30 seconds"
