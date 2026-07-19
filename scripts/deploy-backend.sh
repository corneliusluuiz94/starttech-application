#!/usr/bin/env bash
set -euo pipefail

: "${ECR_REPO_URL:?Set ECR_REPO_URL env var}"
: "${EKS_CLUSTER_NAME:?Set EKS_CLUSTER_NAME env var}"
: "${AWS_REGION:=us-east-1}"

GIT_SHA="$(git rev-parse --short HEAD)"
IMAGE_TAG="${ECR_REPO_URL}:${GIT_SHA}"

cd "$(dirname "${BASH_SOURCE[0]}")/../backend"

echo "=== Running Go tests ==="
go test ./...

echo "=== Building Docker image: $IMAGE_TAG ==="
docker build -t "$IMAGE_TAG" .

echo "=== Scanning image for vulnerabilities (Trivy) ==="
trivy image --exit-code 1 --severity CRITICAL,HIGH "$IMAGE_TAG" || {
  echo "Vulnerability scan failed. Aborting deploy."
  exit 1
}

echo "=== Authenticating to ECR ==="
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REPO_URL"

echo "=== Pushing image ==="
docker push "$IMAGE_TAG"

echo "=== Updating kubeconfig ==="
aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION"

echo "=== Updating deployment manifest with new image tag ==="
cd ../k8s
sed -i.bak "s|image: .*|image: ${IMAGE_TAG}|" deployment.yaml && rm -f deployment.yaml.bak

echo "=== Applying manifests ==="
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

echo "=== Verifying rollout ==="
kubectl rollout status deployment/backend-api --timeout=180s

echo "=== Backend deployment complete: $IMAGE_TAG ==="
