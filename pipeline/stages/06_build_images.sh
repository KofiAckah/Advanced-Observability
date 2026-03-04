#!/usr/bin/env bash
# Stage 6 — Build Docker Images
set -euo pipefail

echo '=== Building Docker images ==='

echo "--- Building backend image (tag: ${IMAGE_TAG}) ---"
docker build \
    -t "${BACKEND_ECR_REPO}:${IMAGE_TAG}" \
    -t "${BACKEND_ECR_REPO}:latest" \
    SpendWise-Core-App/backend

echo "--- Building frontend image (tag: ${IMAGE_TAG}) ---"
docker build \
    -t "${FRONTEND_ECR_REPO}:${IMAGE_TAG}" \
    -t "${FRONTEND_ECR_REPO}:latest" \
    SpendWise-Core-App/frontend

echo "✅ Both images built successfully (build #${IMAGE_TAG})"
