#!/usr/bin/env bash
# Stage 1 — Checkout Application Source Code
set -euo pipefail

echo '=== Checking out SpendWise-Core-App source code ==='
rm -rf SpendWise-Core-App
git clone https://github.com/KofiAckah/SpendWise-Core-App.git
mkdir -p security-reports
echo '✅ Source code checked out successfully'
