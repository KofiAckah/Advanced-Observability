#!/usr/bin/env bash
# Stage 11 — Verify CodeDeploy Blue/Green Deployment
# Polls until the deployment reaches Succeeded (or fails on Failed/Stopped).
#
# CodeDeploy lifecycle stages for ECS blue/green:
#   Created → Queued → InProgress → Ready (traffic shifted, 5-min wait) → Succeeded
#   Any step can transition to: Failed | Stopped
set -euo pipefail

echo '=== Verifying CodeDeploy Blue/Green Deployment ==='

# Read deployment ID written by Stage 10
if [ ! -f /tmp/codedeploy_deployment_id.txt ]; then
    echo "❌ /tmp/codedeploy_deployment_id.txt not found — Stage 10 may have failed"
    exit 1
fi
DEPLOYMENT_ID=$(cat /tmp/codedeploy_deployment_id.txt)
echo "Deployment ID: ${DEPLOYMENT_ID}"
echo "Polling every 15 s (max 48 attempts = 12 min)"
echo ""

for i in $(seq 1 48); do
    DEPLOY_JSON=$(aws deploy get-deployment \
        --deployment-id "${DEPLOYMENT_ID}" \
        --region "${AWS_REGION}" \
        --output json)

    STATUS=$(echo "$DEPLOY_JSON" | python3 -c \
        "import json,sys; print(json.load(sys.stdin)['deploymentInfo']['status'])")

    # Try to extract a human-readable progress description
    set +e
    DESCRIPTION=$(echo "$DEPLOY_JSON" | python3 -c \
        "import json,sys
d=json.load(sys.stdin)['deploymentInfo']
print(d.get('deploymentStatusMessages', [''])[0] or d.get('additionalDeploymentStatusInfo','') or '')" 2>/dev/null)
    set -e

    echo "Attempt $i/48 — status=${STATUS} ${DESCRIPTION}"

    # ── Terminal: success ──────────────────────────────────────
    if [ "$STATUS" = "Succeeded" ]; then
        echo ""
        echo "✅ CodeDeploy deployment SUCCEEDED"
        echo "   Deployment ID : ${DEPLOYMENT_ID}"
        echo "   Blue/green traffic shift complete."

        # Print final deployment summary
        echo ""
        echo "--- Deployment summary ---"
        aws deploy get-deployment \
            --deployment-id "${DEPLOYMENT_ID}" \
            --region "${AWS_REGION}" \
            --query 'deploymentInfo.{Status:status,Creator:creator,Complated:completeTime,TaskSet:deploymentGroupName}' \
            --output table
        break
    fi

    # ── Terminal: failure ──────────────────────────────────────
    if [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Stopped" ]; then
        echo ""
        echo "❌ CodeDeploy deployment ${STATUS}"

        echo "--- Error information ---"
        aws deploy get-deployment \
            --deployment-id "${DEPLOYMENT_ID}" \
            --region "${AWS_REGION}" \
            --query 'deploymentInfo.errorInformation' \
            --output json

        echo "--- Deployment events ---"
        aws deploy list-deployment-instances \
            --deployment-id "${DEPLOYMENT_ID}" \
            --region "${AWS_REGION}" \
            --output json 2>/dev/null || true

        echo ""
        echo "Check the AWS CodeDeploy console for full step-by-step logs:"
        echo "  https://${AWS_REGION}.console.aws.amazon.com/codesuite/codedeploy/deployments/${DEPLOYMENT_ID}"
        exit 1
    fi

    # Reached 'Ready' state = traffic shifted, blue termination timer ticking (5 min)
    if [ "$STATUS" = "Ready" ]; then
        echo "  ↳ Traffic shifted to green. Waiting for blue task termination (5-min window)..."
    fi

    sleep 15
done

# If we exit the loop with last status not Succeeded, the timeout fired (Jenkins wrapper)
echo "--- Final deployment status ---"
aws deploy get-deployment \
    --deployment-id "${DEPLOYMENT_ID}" \
    --region "${AWS_REGION}" \
    --query 'deploymentInfo.{Status:status,StartTime:startTime,CompleteTime:completeTime}' \
    --output table

