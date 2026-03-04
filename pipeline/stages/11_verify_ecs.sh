#!/usr/bin/env bash
# Stage 11 — Verify ECS Deployment (polls until stable, 8 min max via Jenkins timeout)
set -euo pipefail

echo '=== Waiting for ECS service to stabilize ==='
echo "--- Waiting for service to reach steady state ---"

STABLE_COUNT=0
for i in $(seq 1 24); do
    ROLLOUT=$(aws ecs describe-services \
        --region "${AWS_REGION}" \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}" \
        --no-cli-pager \
        --query 'services[0].deployments[?status==`PRIMARY`].rolloutState | [0]' \
        --output text)

    RUNNING=$(aws ecs describe-services \
        --region "${AWS_REGION}" \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}" \
        --no-cli-pager \
        --query 'services[0].deployments[?status==`PRIMARY`].runningCount | [0]' \
        --output text)

    DESIRED=$(aws ecs describe-services \
        --region "${AWS_REGION}" \
        --cluster "${ECS_CLUSTER}" \
        --services "${ECS_SERVICE}" \
        --no-cli-pager \
        --query 'services[0].deployments[?status==`PRIMARY`].desiredCount | [0]' \
        --output text)

    echo "Attempt $i/24 — running=$RUNNING desired=$DESIRED rolloutState=$ROLLOUT"

    if [ "$ROLLOUT" = "COMPLETED" ] && [ "$RUNNING" = "$DESIRED" ]; then
        echo "✅ Deployment COMPLETED — service is stable"
        break
    fi

    if [ "$ROLLOUT" = "FAILED" ]; then
        echo "❌ Deployment FAILED — circuit breaker rolled back"
        echo "--- Last 5 ECS service events ---"
        aws ecs describe-services \
            --region "${AWS_REGION}" \
            --cluster "${ECS_CLUSTER}" \
            --services "${ECS_SERVICE}" \
            --no-cli-pager \
            --query 'services[0].events[:5]' \
            --output table
        exit 1
    fi

    # Secondary: running==desired for 2 consecutive checks
    if [ "$DESIRED" -gt "0" ] 2>/dev/null && [ "$RUNNING" = "$DESIRED" ]; then
        STABLE_COUNT=$((STABLE_COUNT + 1))
        echo "  ↳ Stable check $STABLE_COUNT/2 (running==desired)"
        if [ "$STABLE_COUNT" -ge "2" ]; then
            echo "✅ Service stable — running=$RUNNING desired=$DESIRED"
            break
        fi
    else
        STABLE_COUNT=0
    fi

    sleep 15
done

echo "--- Final ECS service state ---"
aws ecs describe-services \
    --region "${AWS_REGION}" \
    --cluster "${ECS_CLUSTER}" \
    --services "${ECS_SERVICE}" \
    --no-cli-pager \
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,TaskDef:taskDefinition}' \
    --output table
