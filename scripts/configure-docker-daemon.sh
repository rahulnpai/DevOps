#!/usr/bin/env bash
# Run with: bash scripts/configure-docker-daemon.sh
# Requires sudo for /etc/docker/daemon.json
set -euo pipefail

echo '{"insecure-registries":["localhost:5000"],"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}' \
    | sudo tee /etc/docker/daemon.json

sudo systemctl restart docker
echo "Docker daemon reconfigured and restarted."
docker info 2>/dev/null | grep -A5 "Insecure Registries"
