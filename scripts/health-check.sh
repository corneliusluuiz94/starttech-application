#!/usr/bin/env bash
set -euo pipefail

: "${APP_DOMAIN:?Set APP_DOMAIN env var, e.g. d1234abcd.cloudfront.net}"

URL="https://${APP_DOMAIN}/api/v1/health"
echo "=== Checking $URL ==="

HTTP_CODE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" "$URL")
BODY=$(cat /tmp/health_response.json)

echo "HTTP status: $HTTP_CODE"
echo "Body: $BODY"

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Health check FAILED (status $HTTP_CODE)"
  exit 1
fi

if echo "$BODY" | grep -q '"status":"ok"'; then
  echo "Health check PASSED"
  exit 0
else
  echo "Health check DEGRADED"
  exit 1
fi
