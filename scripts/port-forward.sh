#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  port-forward.sh — Forward all K8s services to localhost (dev convenience)
#  Usage: bash scripts/port-forward.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

log() { echo "[PORT-FWD] $*"; }

log "Forwarding devops-app → localhost:8000"
kubectl port-forward svc/devops-app-service 8000:8000 -n devops-prod &

log "Forwarding prometheus → localhost:9090"
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring &

log "Forwarding grafana → localhost:3000"
kubectl port-forward svc/grafana 3000:80 -n monitoring &

log "All port-forwards running. Press Ctrl+C to stop."
wait
