#!/usr/bin/env bash
# Stage 13 — Cleanup Old Docker Images and ECS Task Definition Revisions
set -euo pipefail

echo '=== Cleaning up old Docker images and ECS task revisions ==='

# ── Local Jenkins Docker images (keep last 3 builds) ────────────
docker images "${BACKEND_ECR_REPO}" --format '{{.Tag}}' | \
    grep -E '^[0-9]+$' | sort -rn | tail -n +4 | \
    xargs -r -I{} docker rmi "${BACKEND_ECR_REPO}:{}" || true

docker images "${FRONTEND_ECR_REPO}" --format '{{.Tag}}' | \
    grep -E '^[0-9]+$' | sort -rn | tail -n +4 | \
    xargs -r -I{} docker rmi "${FRONTEND_ECR_REPO}:{}" || true

# ── ECR remote images managed by lifecycle policy (keeps last 5) ─
echo "ECR lifecycle policy manages remote image retention automatically"

# ── Deregister old ECS task definition revisions (keep last 3) ──
echo "--- Deregistering old ECS task definition revisions ---"
ALL_REVISIONS=$(aws ecs list-task-definitions \
    --region "${AWS_REGION}" \
    --family-prefix "${TASK_FAMILY}" \
    --status ACTIVE \
    --no-cli-pager \
    --query 'taskDefinitionArns' \
    --output text | tr '\t' '\n' | sort -t: -k7 -rn)

KEEP=3
COUNT=0
for ARN in $ALL_REVISIONS; do
    COUNT=$((COUNT + 1))
    if [ "$COUNT" -gt "$KEEP" ]; then
        echo "Deregistering old revision: $ARN"
        aws ecs deregister-task-definition \
            --task-definition "$ARN" \
            --region "${AWS_REGION}" \
            --no-cli-pager > /dev/null
    fi
done

echo "✅ Cleanup complete (kept last $KEEP task definition revisions)"
