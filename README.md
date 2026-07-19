# starttech-application

React frontend + Golang backend + Kubernetes manifests for StartTech, deployed onto
the infrastructure provisioned by `starttech-infra`.

## Structure

```
frontend/         React SPA (Vite). Calls the API via relative paths (/api/v1/...).
backend/          Golang REST API. Health check at /api/v1/health and /health.
                  Reads REDIS_HOST and MONGO_URI from env vars. Structured JSON logs.
k8s/               deployment.yaml, service.yaml, ingress.yaml (ALB ingress class)
scripts/           deploy-frontend.sh, deploy-backend.sh, health-check.sh, rollback.sh
.github/workflows/ frontend-ci-cd.yml, backend-ci-cd.yml
```

## Frontend

- Talks to the backend using **relative paths only** (`/api/v1/health`), never a
  hardcoded domain. This works because CloudFront (from `starttech-infra`) routes
  `/api/*` to the ALB on the same HTTPS origin as the S3-hosted static site — no
  mixed-content blocking, no CORS domain juggling.
- Client-side routes (e.g. `/dashboard`) are handled by React Router; CloudFront's
  403/404 → `/index.html` (200) rewrite makes hard refreshes on those routes work.

## Backend

- `GET /api/v1/health` (and `/health`) returns `{"status": "...", "checks": {...}}`,
  pinging Redis and MongoDB if configured.
- Config via env vars: `REDIS_HOST` (ElastiCache endpoint), `MONGO_URI` (Atlas
  connection string) — injected via the `backend-secrets` Kubernetes Secret
  referenced in `k8s/deployment.yaml`.
- Logs are structured JSON to stdout for FluentBit / Container Insights.

## Kubernetes

- `deployment.yaml`: `RollingUpdate` with `maxSurge: 1`, `maxUnavailable: 0` — zero
  downtime deploys, container port `8080`.
- `service.yaml`: `NodePort` service on port 8080.
- `ingress.yaml`: `alb` ingress class; the AWS Load Balancer Controller provisions the
  ALB that `starttech-infra`'s CloudFront distribution (`ALB-Backend` origin) fronts.

**Before first apply**, create the referenced secret, e.g.:
```bash
kubectl create secret generic backend-secrets \
  --from-literal=redis-host="<elasticache-endpoint>:6379" \
  --from-literal=mongo-uri="<mongodb-atlas-connection-string>"
```

## CI/CD

- **frontend-ci-cd.yml**: on `frontend/**` changes → `npm ci` → `npm audit` →
  `npm run build` → `aws s3 sync` → CloudFront invalidation.
- **backend-ci-cd.yml**: on `backend/**` or `k8s/**` changes → `go test` → Docker
  build (tagged with the short git SHA) → Trivy scan → push to ECR → update
  `k8s/deployment.yaml` image tag → `kubectl apply -f k8s/` → `kubectl rollout status`.

Required repository secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
`S3_BUCKET_NAME`, `CLOUDFRONT_DISTRIBUTION_ID`.

## Local scripts

```bash
S3_BUCKET=... CLOUDFRONT_DISTRIBUTION_ID=... ./scripts/deploy-frontend.sh
ECR_REPO_URL=... EKS_CLUSTER_NAME=starttech-cluster ./scripts/deploy-backend.sh
APP_DOMAIN=d1234abcd.cloudfront.net ./scripts/health-check.sh
EKS_CLUSTER_NAME=starttech-cluster ./scripts/rollback.sh
```
