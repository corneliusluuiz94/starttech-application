#!/usr/bin/env bash
set -euo pipefail

: "${S3_BUCKET:?Set S3_BUCKET env var}"
: "${CLOUDFRONT_DISTRIBUTION_ID:?Set CLOUDFRONT_DISTRIBUTION_ID env var}"

cd "$(dirname "${BASH_SOURCE[0]}")/../frontend"

echo "=== Installing dependencies ==="
npm ci

echo "=== Running security audit ==="
npm audit --audit-level=high || true

echo "=== Building production bundle ==="
npm run build

echo "=== Syncing build/ to S3 bucket: $S3_BUCKET ==="
aws s3 sync dist/ "s3://${S3_BUCKET}" --delete

echo "=== Invalidating CloudFront cache ==="
aws cloudfront create-invalidation \
  --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
  --paths "/*"

echo "=== Frontend deployment complete ==="
