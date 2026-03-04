#!/usr/bin/env bash
# Stage 7 — Image Scan with Trivy
set -euo pipefail

echo '=== Scanning Docker images for vulnerabilities ==='

mkdir -p "${WORKSPACE}/.trivy-cache"

echo "--- Scanning backend image ---"
set +e
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${WORKSPACE}/${REPORTS_DIR}:/reports" \
    -v "${WORKSPACE}/.trivy-cache:/root/.cache/trivy" \
    aquasec/trivy:latest image \
    --exit-code 1 \
    --severity HIGH,CRITICAL \
    --ignore-unfixed \
    --scanners vuln \
    --format json \
    --output /reports/trivy-backend-report.json \
    "${BACKEND_ECR_REPO}:${IMAGE_TAG}"
TRIVY_BACKEND_EXIT=$?
set -e

echo "--- Scanning frontend image ---"
set +e
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${WORKSPACE}/${REPORTS_DIR}:/reports" \
    -v "${WORKSPACE}/.trivy-cache:/root/.cache/trivy" \
    aquasec/trivy:latest image \
    --exit-code 1 \
    --severity HIGH,CRITICAL \
    --ignore-unfixed \
    --scanners vuln \
    --format json \
    --output /reports/trivy-frontend-report.json \
    "${FRONTEND_ECR_REPO}:${IMAGE_TAG}"
TRIVY_FRONTEND_EXIT=$?
set -e

# Print finding counts before failing
for img_name in backend frontend; do
    report="${REPORTS_DIR}/trivy-${img_name}-report.json"
    if [ -f "$report" ]; then
        COUNT=$(python3 -c "import json; d=json.load(open('$report')); print(sum(len(r.get('Vulnerabilities') or []) for r in d.get('Results',[])))" 2>/dev/null || echo '?')
        echo "[$img_name] HIGH/CRITICAL (with fix available): $COUNT"
    fi
done

if [ "$TRIVY_BACKEND_EXIT" -ne 0 ] || [ "$TRIVY_FRONTEND_EXIT" -ne 0 ]; then
    echo "❌ Trivy found HIGH/CRITICAL fixable vulnerabilities — blocking pipeline"
    exit 1
fi

echo '✅ No HIGH/CRITICAL fixable vulnerabilities found in either image'
