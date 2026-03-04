#!/usr/bin/env bash
# Stage 9 — Push Images to AWS ECR
set -euo pipefail

echo '=== Authenticating with AWS ECR and pushing images ==='

aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "--- Pushing backend images ---"
docker push "${BACKEND_ECR_REPO}:${IMAGE_TAG}"
docker push "${BACKEND_ECR_REPO}:latest"

echo "--- Pushing frontend images ---"
docker push "${FRONTEND_ECR_REPO}:${IMAGE_TAG}"
docker push "${FRONTEND_ECR_REPO}:latest"

echo '✅ All images pushed to ECR'
