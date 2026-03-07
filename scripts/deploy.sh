#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  deploy.sh — Build → Push → Rolling deploy to Kubernetes
#  Usage: bash scripts/deploy.sh [IMAGE_TAG]
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[DEPLOY]${NC} $*"; }
die() { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

REGISTRY="localhost:5000"
IMAGE_NAME="devops-mca-app"
TAG="${1:-$(git rev-parse --short HEAD 2>/dev/null || echo "latest")}"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"
NAMESPACE="devops-prod"
DEPLOYMENT="devops-app"

log "Building image: ${FULL_IMAGE}"
docker build -f docker/Dockerfile \
    -t "${FULL_IMAGE}" \
    -t "${REGISTRY}/${IMAGE_NAME}:latest" \
    .

log "Pushing to local registry..."
docker push "${FULL_IMAGE}"
docker push "${REGISTRY}/${IMAGE_NAME}:latest"

log "Deploying to Kubernetes..."
kubectl set image deployment/"${DEPLOYMENT}" \
    app="${FULL_IMAGE}" \
    -n "${NAMESPACE}"

log "Waiting for rollout..."
kubectl rollout status deployment/"${DEPLOYMENT}" \
    -n "${NAMESPACE}" \
    --timeout=120s

log "Verifying pods..."
kubectl get pods -n "${NAMESPACE}" -l app=devops-app

MINIKUBE_IP=$(minikube ip)
log "Smoke test..."
for i in 1 2 3 4 5; do
    STATUS=$(curl -s -o /dev/null -w '%{http_code}' "http://${MINIKUBE_IP}:30080/health") || true
    if [[ "$STATUS" == "200" ]]; then
        log "Health check PASSED"
        break
    fi
    echo "  Attempt $i — status: $STATUS"
    sleep 5
done

echo ""
echo -e "${GREEN}Deploy complete — image: ${FULL_IMAGE}${NC}"
