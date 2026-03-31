#!/usr/bin/env bash
set -euo pipefail

echo "=== StockPulse Deploy ==="

echo "Pulling latest code..."
git pull origin main

echo "Building containers..."
docker compose build

echo "Running migrations..."
docker compose run --rm app bin/rails db:migrate

echo "Restarting services..."
docker compose up -d

echo "Deploy complete!"
