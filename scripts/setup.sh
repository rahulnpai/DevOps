#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  setup.sh — Bootstrap the entire DevOps platform
#  Usage: bash scripts/setup.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[SETUP]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()  { echo -e "${RED}[ERR]${NC}   $*" >&2; exit 1; }

# ── 0. Pre-flight ─────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Do NOT run as root. Run as regular user (sudo will be used internally)."

log "Installing Ansible..."
sudo apt-get update -qq
sudo apt-get install -y ansible python3-pip
pip3 install --quiet ansible-core

# ── 1. Run Ansible to install all tools ───────────────────────────────────────
log "Running Ansible playbook..."
ansible-playbook -i ansible/inventory.ini ansible/setup-all.yml -K

# ── 2. Start local Docker registry ───────────────────────────────────────────
log "Starting local Docker registry..."
docker run -d --name local-registry --restart=unless-stopped \
    -p 5000:5000 registry:2 2>/dev/null || warn "Registry already running"

# ── 3. Build and push app image ───────────────────────────────────────────────
log "Building FastAPI app image..."
docker build -f docker/Dockerfile -t localhost:5000/devops-mca-app:latest .
docker push localhost:5000/devops-mca-app:latest

# ── 4. Start minikube ─────────────────────────────────────────────────────────
log "Starting minikube cluster..."
minikube start \
    --driver=docker \
    --cpus=4 \
    --memory=6144 \
    --disk-size=20g \
    --insecure-registry="localhost:5000" \
    --addons=ingress,metrics-server \
    2>/dev/null || warn "minikube already running"

# Allow minikube to pull from local registry
log "Configuring minikube registry access..."
minikube ssh -- "sudo sh -c 'echo {\\\"insecure-registries\\\":[\\\"host.minikube.internal:5000\\\"]} > /etc/docker/daemon.json && systemctl restart docker'" || true

# ── 5. Deploy via Terraform ───────────────────────────────────────────────────
log "Initialising Terraform..."
cd terraform
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
cd ..

# ── 6. Start Jenkins ──────────────────────────────────────────────────────────
log "Starting Jenkins..."
docker compose -f jenkins/jenkins-docker-compose.yml up -d

# ── 7. Start monitoring stack (docker-compose) ────────────────────────────────
log "Starting Prometheus + Grafana..."
docker compose -f docker/docker-compose.yml up -d prometheus grafana

# ── 8. Print access URLs ──────────────────────────────────────────────────────
MINIKUBE_IP=$(minikube ip)
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  DevOps MCA Platform — READY${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "  App (minikube):  http://${MINIKUBE_IP}:30080"
echo -e "  Jenkins:         http://localhost:8080"
echo -e "  Prometheus:      http://localhost:9090"
echo -e "  Grafana:         http://localhost:3000  (admin/admin123)"
echo -e "  Registry:        http://localhost:5000"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
