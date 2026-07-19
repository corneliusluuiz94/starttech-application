#!/usr/bin/env bash
set -euo pipefail

: "${EKS_CLUSTER_NAME:?Set EKS_CLUSTER_NAME env var}"
: "${AWS_REGION:=us-east-1}"

aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

echo "=== Current rollout history ==="
kubectl rollout history deployment/backend-api

echo "=== Rolling back to previous revision ==="
kubectl rollout undo deployment/backend-api

echo "=== Verifying rollback ==="
kubectl rollout status deployment/backend-api --timeout=180s

echo "=== Rollback complete ==="
