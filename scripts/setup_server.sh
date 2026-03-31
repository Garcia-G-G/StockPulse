#!/usr/bin/env bash
set -euo pipefail

echo "=== StockPulse Server Setup ==="

echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "Installing Docker Compose..."
apt-get install -y docker-compose-plugin

echo "Creating app user..."
useradd -m -s /bin/bash stockpulse || true
usermod -aG docker stockpulse

echo "Creating directories..."
mkdir -p /opt/stockpulse /backups
chown stockpulse:stockpulse /opt/stockpulse /backups

echo "Server setup complete. Clone the repo to /opt/stockpulse and run deploy.sh"
