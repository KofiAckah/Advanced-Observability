#!/usr/bin/env bash
# Stage 5 — SAST Scan with CodeQL
set -euo pipefail

echo '=== Running CodeQL static analysis ==='

# Create CodeQL database from backend source
/opt/codeql-cli/codeql/codeql database create \
    "${WORKSPACE}/codeql-db" \
    --language=javascript \
    --source-root="${WORKSPACE}/SpendWise-Core-App/backend" \
    --overwrite

# Run security queries
/opt/codeql-cli/codeql/codeql database analyze \
    "${WORKSPACE}/codeql-db" \
    --format=sarif-latest \
    --output="${REPORTS_DIR}/codeql-results.sarif" \
    javascript-security-extended

echo "CodeQL analysis complete"

# Gate: count error-level (HIGH/CRITICAL) findings in the SARIF output
CODEQL_HIGH=$(python3 - <<'PYEOF' 2>/dev/null || echo 0
import json, os
try:
    sarif = json.load(open(os.environ['REPORTS_DIR'] + '/codeql-results.sarif'))
    count = sum(
        1 for run in sarif.get('runs', [])
        for result in run.get('results', [])
        if result.get('level') == 'error'
    )
    print(count)
except Exception:
    print(0)
PYEOF
)

if [ "${CODEQL_HIGH:-0}" -gt "0" ]; then
    echo "❌ CodeQL found ${CODEQL_HIGH} HIGH/CRITICAL findings — blocking pipeline"
    python3 - <<'PYEOF' || true
import json, os
try:
    sarif = json.load(open(os.environ['REPORTS_DIR'] + '/codeql-results.sarif'))
    for run in sarif.get('runs', []):
        for result in run.get('results', []):
            if result.get('level') == 'error':
                loc = result.get('locations', [{}])[0].get('physicalLocation', {})
                f = loc.get('artifactLocation', {}).get('uri', 'unknown')
                ln = loc.get('region', {}).get('startLine', '?')
                msg = result.get('message', {}).get('text', '')[:120]
                print(f'  [HIGH] {result.get("ruleId","?")} at {f}:{ln} — {msg}')
except Exception as e:
    print(f'Could not parse SARIF: {e}')
PYEOF
    exit 1
fi

echo '✅ No HIGH/CRITICAL CodeQL findings'
