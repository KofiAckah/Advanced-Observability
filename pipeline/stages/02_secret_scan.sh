#!/usr/bin/env bash
# Stage 2 — Secret Scanning with Gitleaks
set -euo pipefail

echo '=== Scanning for hardcoded secrets and credentials ==='

# set +e: Gitleaks exits 1 when secrets found. Without this,
# bash set -e fires before GITLEAKS_EXIT=$? runs.
set +e
docker run --rm \
    -v "${WORKSPACE}/SpendWise-Core-App:/path" \
    zricethezav/gitleaks:latest \
    detect \
    --source /path \
    --report-format json \
    --report-path /path/gitleaks-report.json \
    --exit-code 1
GITLEAKS_EXIT=$?
set -e

cp SpendWise-Core-App/gitleaks-report.json "${REPORTS_DIR}/" 2>/dev/null || true

if [ "$GITLEAKS_EXIT" -ne 0 ]; then
    echo "❌ Gitleaks detected secrets or credentials — blocking pipeline"
    exit 1
fi

echo '✅ No secrets detected'
