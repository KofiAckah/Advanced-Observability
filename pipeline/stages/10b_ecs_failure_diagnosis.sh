#!/usr/bin/env bash
# Stage 10b — ECS Failure Diagnosis (runs in post.failure of Deploy stage)
set -euo pipefail

echo "=== ECS FAILURE DIAGNOSIS ==="

echo "--- Most recently stopped task ---"
STOPPED=$(aws ecs list-tasks \
    --cluster "${ECS_CLUSTER}" \
    --region "${AWS_REGION}" \
    --desired-status STOPPED \
    --query 'taskArns[0]' \
    --output text 2>/dev/null || echo "")

if [ -n "$STOPPED" ] && [ "$STOPPED" != "None" ]; then
    aws ecs describe-tasks \
        --cluster "${ECS_CLUSTER}" \
        --tasks "$STOPPED" \
        --region "${AWS_REGION}" \
        --no-cli-pager \
        --query 'tasks[0].{StopCode:stopCode,StopReason:stoppedReason,Containers:containers[*].{Name:name,ExitCode:exitCode,Reason:reason}}' \
        --output json || true

    TASK_ID=$(echo "$STOPPED" | rev | cut -d'/' -f1 | rev)
    echo "--- Last 30 backend log lines ---"
    aws logs get-log-events \
        --log-group-name "/ecs/${PROJECT_NAME}-${ENVIRONMENT}" \
        --log-stream-name "backend/spendwise-backend/${TASK_ID}" \
        --region "${AWS_REGION}" \
        --limit 30 \
        --no-cli-pager \
        --query 'events[*].message' \
        --output text 2>/dev/null || echo "(no CloudWatch logs found for this task)"
fi

echo "--- Last 5 ECS service events ---"
aws ecs describe-services \
    --cluster "${ECS_CLUSTER}" \
    --services "${ECS_SERVICE}" \
    --region "${AWS_REGION}" \
    --no-cli-pager \
    --query 'services[0].events[:5].[message]' \
    --output text || true
