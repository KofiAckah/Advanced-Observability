#!/usr/bin/env bash
# Stage 9b — DB Migration (run init.sql against RDS)
set -euo pipefail

echo '=== Running DB schema migration against RDS ==='

DB_HOST=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/${ENVIRONMENT}/app/db_host" \
    --region "${AWS_REGION}" \
    --query "Parameter.Value" \
    --output text)

DB_USER=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/${ENVIRONMENT}/db/user" \
    --with-decryption \
    --region "${AWS_REGION}" \
    --query "Parameter.Value" \
    --output text)

DB_PASS=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/${ENVIRONMENT}/db/password" \
    --with-decryption \
    --region "${AWS_REGION}" \
    --query "Parameter.Value" \
    --output text)

DB_NAME=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/${ENVIRONMENT}/db/name" \
    --region "${AWS_REGION}" \
    --query "Parameter.Value" \
    --output text)

echo "Running init.sql against RDS host: $DB_HOST"

docker run --rm \
    -e PGPASSWORD="$DB_PASS" \
    -v "${WORKSPACE}/SpendWise-Core-App/backend:/sql" \
    postgres:16-alpine \
    psql \
        --host="$DB_HOST" \
        --port=5432 \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --file=/sql/init.sql \
        --no-password

echo '✅ DB migration complete'
