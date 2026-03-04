#!/usr/bin/env bash
# Stage 14 — Load Test (k6)
#
# Runs a short k6 load test against the live ECS endpoint to:
#   • generate RED metrics (Rate / Errors / Duration) in Prometheus
#   • produce real distributed traces in Jaeger
#   • validate alert thresholds under realistic traffic
#
# Prerequisites (Jenkins):
#   - Docker available on the agent
#   - APP_URL env var set (resolved from ECS task) OR auto-discovered below
#
# This stage is SKIPPED by default in the Jenkinsfile (when { return false }).
# Enable it by removing / modifying that condition for a manual load-test run.
# ==============================================================
set -euo pipefail

# ── Resolve target URL ────────────────────────────────────────
APP_URL="${APP_URL:-}"
if [[ -z "$APP_URL" ]]; then
  echo "=== Resolving ECS task public IP ==="
  TASK_ARN=$(aws ecs list-tasks \
    --region "${AWS_REGION:-eu-west-1}" \
    --cluster "${ECS_CLUSTER:-advanced-monitor-spendwise-dev-cluster}" \
    --query "taskArns[0]" --output text)

  TASK_IP=$(aws ecs describe-tasks \
    --region "${AWS_REGION:-eu-west-1}" \
    --cluster "${ECS_CLUSTER:-advanced-monitor-spendwise-dev-cluster}" \
    --tasks "$TASK_ARN" \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value | [0]" \
    --output text | xargs -I{} aws ec2 describe-network-interfaces \
      --region "${AWS_REGION:-eu-west-1}" \
      --network-interface-ids {} \
      --query "NetworkInterfaces[0].Association.PublicIp" \
      --output text)

  APP_URL="http://${TASK_IP}"
fi

echo "=== Load-testing: ${APP_URL} ==="

# ── Inline k6 script ─────────────────────────────────────────
K6_SCRIPT=$(cat <<'K6EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },   // ramp up
    { duration: '60s', target: 10 },   // steady state
    { duration: '20s', target: 30 },   // spike
    { duration: '10s', target: 0  },   // ramp down
  ],
  thresholds: {
    http_req_failed:   ['rate<0.05'],    // <5% error rate
    http_req_duration: ['p(95)<500'],    // 95th pct < 500 ms
  },
};

const BASE = __ENV.APP_URL || 'http://localhost';

export default function () {
  // GET all expenses
  const list = http.get(`${BASE}/api/expenses`);
  check(list, { 'list expenses 200': (r) => r.status === 200 });

  // POST a new expense
  const payload = JSON.stringify({
    itemName: `LoadTest-${Date.now()}`,
    amount: (Math.random() * 100).toFixed(2),
    category: 'Other',
  });
  const post = http.post(`${BASE}/api/expenses`, payload, {
    headers: { 'Content-Type': 'application/json' },
  });
  check(post, { 'add expense 201': (r) => r.status === 201 });

  // GET total
  const total = http.get(`${BASE}/api/expenses/total`);
  check(total, { 'total 200': (r) => r.status === 200 });

  sleep(Math.random() * 0.5 + 0.1);
}
K6EOF
)

REPORTS_DIR="${REPORTS_DIR:-security-reports}"
mkdir -p "${REPORTS_DIR}"

echo "=== Running k6 load test (docker) ==="
echo "$K6_SCRIPT" > /tmp/k6_script.js

docker run --rm \
  -v /tmp/k6_script.js:/k6_script.js \
  -e APP_URL="${APP_URL}" \
  grafana/k6:0.54.0 run \
    --out json=/dev/null \
    --summary-export /dev/stdout \
    /k6_script.js \
  | tee "${REPORTS_DIR}/load_test_summary.json"

echo "=== Load test complete. Summary saved to ${REPORTS_DIR}/load_test_summary.json ==="
