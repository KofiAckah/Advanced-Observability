#!/usr/bin/env bash
# Stage 8 — Generate SBOM with Syft (CycloneDX JSON)
set -euo pipefail

echo '=== Generating Software Bill of Materials ==='

echo "--- Generating SBOM for backend image ---"
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${WORKSPACE}/security-reports:/output" \
    anchore/syft:latest \
    "docker:${BACKEND_ECR_REPO}:${IMAGE_TAG}" \
    -o cyclonedx-json=/output/sbom-backend.json

echo "--- Generating SBOM for frontend image ---"
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${WORKSPACE}/security-reports:/output" \
    anchore/syft:latest \
    "docker:${FRONTEND_ECR_REPO}:${IMAGE_TAG}" \
    -o cyclonedx-json=/output/sbom-frontend.json

echo '✅ SBOM generated for both images'
