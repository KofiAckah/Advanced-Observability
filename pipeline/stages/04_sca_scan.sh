#!/usr/bin/env bash
# Stage 4 — SCA Scan with Snyk
# Requires: SNYK_TOKEN injected by Jenkins withCredentials block
set -euo pipefail

echo '=== Scanning dependencies for known vulnerabilities ==='

# Install snyk outside the app directory so its own deps are never scanned
npm install snyk --save-dev --prefix "${WORKSPACE}/.snyk-cli" --loglevel=error
SNYK_BIN="${WORKSPACE}/.snyk-cli/node_modules/.bin/snyk"

${SNYK_BIN} auth "${SNYK_TOKEN}"

# Scan only production deps; split stdout (JSON) from stderr (progress text)
# exit 0 = clean, exit 1 = HIGH/CRITICAL found, exit 2 = scan error
set +e
${SNYK_BIN} test SpendWise-Core-App/backend \
    --severity-threshold=high \
    --production \
    --json \
    > "${REPORTS_DIR}/snyk-report.json" \
    2> "${REPORTS_DIR}/snyk-stderr.log"
SNYK_EXIT=$?
set -e

if [ "$SNYK_EXIT" -eq 1 ]; then
    echo "❌ Snyk found HIGH/CRITICAL vulnerabilities — blocking pipeline"
    python3 - <<'PYEOF'
import json, sys, os
try:
    data = json.load(open(os.environ['REPORTS_DIR'] + '/snyk-report.json'))
    vulns = [v for v in data.get('vulnerabilities', []) if v.get('severity') in ('high', 'critical')]
    print(f'Found {len(vulns)} HIGH/CRITICAL vulnerabilities:')
    for v in vulns[:10]:
        print(f'  [{v["severity"].upper()}] {v["id"]} in {v["packageName"]}@{v["version"]}')
except Exception as e:
    print(f'Could not parse report: {e}')
PYEOF
    exit 1
elif [ "$SNYK_EXIT" -eq 2 ]; then
    echo "❌ Snyk scan error — check token validity and network access"
    cat "${REPORTS_DIR}/snyk-report.json" || true
    exit 1
fi

echo '✅ No HIGH/CRITICAL vulnerabilities found'
