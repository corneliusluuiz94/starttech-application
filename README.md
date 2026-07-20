# starttech-application

React frontend + Golang backend + Kubernetes manifests for the StartTech DevOps Assessment, deployed onto the infrastructure provisioned by the companion **starttech-infra** repository.

---

# Architecture

- **Frontend:** React (Vite)
- **Backend:** Golang REST API
- **Container Registry:** Amazon ECR (`starttech-backend-api`)
- **Container Orchestration:** Amazon EKS (`starttech-cluster`)
- **Caching:** Amazon ElastiCache Redis (`starttech-redis`)
- **Database:** MongoDB Atlas
- **Load Balancer:** AWS Load Balancer Controller (Application Load Balancer Ingress)
- **CDN:** Amazon CloudFront
- **Static Hosting:** Amazon S3
- **Infrastructure as Code:** Terraform (see `starttech-infra`)
- **CI/CD:** GitHub Actions

---

# Repository Structure

```text
frontend/               React Single Page Application (Vite)
backend/                Golang REST API
k8s/                    Kubernetes Deployment, Service and Ingress manifests
scripts/                Deployment, health-check and rollback scripts
.github/workflows/      Frontend and Backend CI/CD pipelines
```

---

# Frontend

The frontend is a React application built with Vite.

Features include:

- Uses **relative API paths** (`/api/v1/...`) instead of hardcoded backend URLs.
- Intended to be served from Amazon S3 through Amazon CloudFront.
- CloudFront routes `/api/*` requests to the backend Application Load Balancer, allowing both frontend and backend to share the same HTTPS origin.
- Supports client-side routing through CloudFront custom error page rewrites.

---

# Backend

The backend is a Golang REST API deployed on Amazon EKS.

Features include:

- Health endpoints:

  - `GET /api/v1/health`
  - `GET /health`

- Performs connectivity checks against:

  - MongoDB Atlas
  - Amazon ElastiCache Redis

- Configuration is supplied through Kubernetes Secrets:

  - `MONGO_URI`
  - `REDIS_HOST`

- Emits structured JSON logs suitable for centralized logging solutions such as Fluent Bit and Amazon CloudWatch.

---

# Kubernetes

The backend is deployed using Kubernetes manifests.

### Deployment

- RollingUpdate strategy
- `maxSurge: 1`
- `maxUnavailable: 0`
- Container port `8080`
- Readiness probe
- Liveness probe
- Resource requests and limits configured

### Service

- Kubernetes NodePort Service
- Exposes the backend on port **8080**

### Ingress

Configured using the AWS Load Balancer Controller.

Features:

- Internet-facing Application Load Balancer
- IP target mode
- Health check endpoint:

```
/api/v1/health
```

- Managed automatically through Kubernetes Ingress resources.

---

# Kubernetes Secret

Before deploying the backend, create the required secret.

```bash
kubectl create secret generic backend-secrets \
  --from-literal=redis-host="<elasticache-endpoint>:6379" \
  --from-literal=mongo-uri="<mongodb-atlas-connection-string>"
```

---

# CI/CD

## Frontend Pipeline

Triggered on changes inside:

```
frontend/**
```

Pipeline stages:

1. Install dependencies
2. Security scan (`npm audit`)
3. Build production assets
4. Upload build to Amazon S3
5. Invalidate Amazon CloudFront cache

---

## Backend Pipeline

Triggered on changes inside:

```
backend/**
k8s/**
```

Pipeline stages:

1. Run Go tests
2. Build Docker image
3. Scan image using Trivy
4. Push image to Amazon ECR
5. Update Kubernetes deployment image
6. Apply Kubernetes manifests
7. Verify deployment rollout

---

Required GitHub Secrets

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `S3_BUCKET_NAME`
- `CLOUDFRONT_DISTRIBUTION_ID`

---

# Deployment Status

The application has been successfully deployed to Amazon EKS.

Verified components:

- ✅ Backend running with two replicas
- ✅ Rolling updates enabled
- ✅ MongoDB Atlas connectivity verified
- ✅ Redis connectivity verified
- ✅ Kubernetes readiness probe passing
- ✅ Kubernetes liveness probe passing
- ✅ AWS Load Balancer Controller installed
- ✅ Application Load Balancer provisioned through Kubernetes Ingress
- ✅ Docker images pushed to Amazon ECR
- ✅ Backend deployment automated through GitHub Actions
- ⚠️ Frontend deployment to Amazon S3 completed; CloudFront backend origin requires final ALB origin update to complete end-to-end API routing

---

# Assessment Requirements Mapping

| Requirement | Status |
|-------------|--------|
| Terraform Infrastructure | ✅ |
| Amazon EKS | ✅ |
| Amazon ECR | ✅ |
| Amazon S3 | ✅ |
| Amazon CloudFront | ⚠️ Pending final ALB origin update |
| MongoDB Atlas | ✅ |
| Amazon ElastiCache Redis | ✅ |
| GitHub Actions CI/CD | ✅ |
| Kubernetes Deployment | ✅ |
| AWS Load Balancer Controller | ✅ |
| ALB Ingress | ✅ |
| Rolling Updates | ✅ |
| Health Endpoint | ✅ |

---

# Local Deployment Scripts

```bash
S3_BUCKET=... CLOUDFRONT_DISTRIBUTION_ID=... ./scripts/deploy-frontend.sh

ECR_REPO_URL=... EKS_CLUSTER_NAME=starttech-cluster ./scripts/deploy-backend.sh

APP_DOMAIN=d1234abcd.cloudfront.net ./scripts/health-check.sh

EKS_CLUSTER_NAME=starttech-cluster ./scripts/rollback.sh
```