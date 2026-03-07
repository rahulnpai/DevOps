#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  cleanup.sh — Tear down everything (for reset / re-demo)
#  Usage: bash scripts/cleanup.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${YELLOW}[CLEANUP]${NC} $*"; }

log "Destroying Terraform resources..."
cd terraform && terraform destroy -auto-approve 2>/dev/null || true; cd ..

log "Deleting Kubernetes namespace..."
kubectl delete namespace devops-prod  --ignore-not-found=true
kubectl delete namespace monitoring   --ignore-not-found=true

log "Stopping minikube..."
minikube stop 2>/dev/null || true

log "Stopping Docker containers..."
docker compose -f docker/docker-compose.yml down -v 2>/dev/null || true
docker compose -f jenkins/jenkins-docker-compose.yml down -v 2>/dev/null || true
docker stop local-registry 2>/dev/null || true
docker rm   local-registry 2>/dev/null || true

log "Pruning Docker..."
docker system prune -f

log "Cleanup complete."
