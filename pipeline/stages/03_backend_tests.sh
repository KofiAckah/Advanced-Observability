#!/usr/bin/env bash
# Stage 3 — Run Backend Unit Tests
set -euo pipefail

echo '=== Running backend unit tests ==='
cd "${WORKSPACE}/SpendWise-Core-App/backend"
npm install
npm test
echo '✅ All backend tests passed'
