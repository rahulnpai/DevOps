# DevOps MCA Project — Architecture & Interview Guide

## Architecture Diagram

```
Developer Laptop (Ubuntu 16GB RAM)
│
├── Git Push → GitHub
│       │
│       └── Webhook → Jenkins (Docker container :8080)
│                       │
│                       ├── Pull source code
│                       ├── Run pytest
│                       ├── docker build (multi-stage)
│                       ├── trivy scan
│                       ├── docker push → Local Registry (:5000)
│                       └── kubectl set image → minikube
│
├── minikube Kubernetes Cluster
│       ├── namespace: devops-prod
│       │     ├── Deployment  (2 replicas, RollingUpdate)
│       │     ├── Service     (NodePort :30080)
│       │     ├── Ingress     (nginx)
│       │     ├── HPA         (2-10 replicas on CPU/mem)
│       │     └── PDB         (minAvailable: 1)
│       │
│       └── namespace: monitoring
│             ├── Prometheus  (kube-prometheus-stack)
│             └── Grafana     (:32000)
│
├── Terraform  → manages k8s resources as code
├── Ansible    → one-command environment setup
└── FastAPI App
      ├── GET /          → root info
      ├── GET /health    → health status
      ├── GET /metrics   → Prometheus exposition
      ├── GET /ready     → k8s readiness probe
      └── GET /live      → k8s liveness probe
```

## Tech Stack Explained (Interview)

| Tool | Purpose | Production Equivalent |
|------|---------|----------------------|
| FastAPI | Microservice | Any REST/gRPC service |
| Docker | Containerisation | AWS ECR images |
| minikube | Local K8s cluster | AWS EKS / GKE |
| Jenkins | CI/CD orchestration | AWS CodePipeline / GitHub Actions |
| Terraform | Infrastructure as Code | Manages EKS, RDS, S3, VPC |
| Ansible | Config management | Replaces manual server setup |
| Prometheus | Metrics collection | AWS CloudWatch / Datadog |
| Grafana | Metrics visualisation | Same in prod |
| Local Registry | Image storage | AWS ECR / Docker Hub |

## Key DevOps Concepts Demonstrated

1. **Zero-downtime deployments** — `maxUnavailable: 0` in rolling update
2. **Pod Disruption Budget** — minimum 1 pod always available during node drain
3. **HPA** — scales 2→10 pods based on CPU 60% / memory 70% thresholds
4. **Liveness vs Readiness probes** — Kubernetes only routes traffic to ready pods
5. **Prometheus annotations** — pods self-register for scraping
6. **Multi-stage Docker build** — final image has no build tools (smaller + secure)
7. **Non-root container** — UID 1001, read-only root filesystem
8. **Infrastructure as Code** — entire K8s state managed by Terraform
9. **Immutable infrastructure** — never patch running containers, always redeploy

## Resume Description

> Designed and deployed a production-grade cloud-native DevOps platform on local
> infrastructure, implementing a full CI/CD pipeline using Jenkins, Docker, and
> Kubernetes (minikube). Automated infrastructure provisioning with Terraform
> (Kubernetes provider) and environment setup with Ansible. Built a FastAPI
> microservice with Prometheus metrics and Grafana dashboards for real-time
> observability. Implemented zero-downtime rolling deployments, HPA autoscaling,
> Pod Disruption Budgets, and container security hardening (non-root, read-only FS).

## Viva Demo Flow

1. Show `tree devops-mca-project/` — folder structure
2. Open `app/main.py` — explain Prometheus middleware
3. Open `docker/Dockerfile` — explain multi-stage build
4. Run `kubectl get all -n devops-prod` — show live pods
5. `kubectl get hpa -n devops-prod` — explain autoscaling
6. Open Jenkins → show pipeline stages
7. Open Grafana → show real-time dashboard
8. Push a code change → demonstrate automatic pipeline trigger
9. Open `terraform/main.tf` — explain IaC pattern
10. Open `ansible/setup-all.yml` — explain idempotent automation
