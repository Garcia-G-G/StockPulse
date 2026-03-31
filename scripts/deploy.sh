#!/usr/bin/env bash
set -euo pipefail

# StockPulse Zero-Downtime Deployment
# Usage: bash scripts/deploy.sh [production|staging] [git-ref]

ENVIRONMENT="${1:-production}"
VERSION="${2:-HEAD}"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="${APP_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HEALTH_URL="http://localhost:3000/api/v1/health"
MAX_HEALTH_ATTEMPTS=30
HEALTH_INTERVAL=2

cd "$APP_DIR"

echo "=== StockPulse Deploy ==="
echo "Environment: ${ENVIRONMENT}"
echo "Version: ${VERSION}"
echo "Timestamp: ${TIMESTAMP}"

# --- Pre-Deploy Checks ---
echo ""
echo "[1/8] Pre-deploy checks..."
if [ "$ENVIRONMENT" = "production" ]; then
    if [ -f ".env" ]; then
        echo "  .env file found"
    else
        echo "ERROR: .env file not found" >&2
        exit 1
    fi
fi

# --- Database Backup ---
echo "[2/8] Creating pre-deploy database backup..."
mkdir -p "$BACKUP_DIR"
if docker compose ps postgres --status running -q 2>/dev/null | grep -q .; then
    docker compose exec -T postgres pg_dump -U stockpulse -Fc -Z 9 stockpulse_production \
        > "${BACKUP_DIR}/pre_deploy_${TIMESTAMP}.dump" 2>/dev/null || echo "  WARN: Backup failed (DB may not exist yet)"
    echo "  Backup: pre_deploy_${TIMESTAMP}.dump"
else
    echo "  Skipping backup (postgres not running)"
fi

# --- Pull Latest Code ---
echo "[3/8] Pulling latest code..."
git fetch --all --prune
if [ "$VERSION" = "HEAD" ]; then
    git pull origin main
else
    git checkout "$VERSION"
fi

# --- Build Images ---
echo "[4/8] Building Docker images..."
docker compose build --no-cache app
docker compose build ai_service

# --- Start Services ---
echo "[5/8] Starting services..."
docker compose up -d postgres redis
echo "  Waiting for database..."
sleep 5

# --- Migrations ---
echo "[6/8] Running database migrations..."
docker compose run --rm app bundle exec rake db:create 2>/dev/null || true
docker compose run --rm app bundle exec rake db:migrate

# --- Deploy App Services ---
echo "[7/8] Deploying application services..."
docker compose up -d

# --- Health Check ---
echo "[8/8] Running health checks..."
HEALTHY=false
for i in $(seq 1 $MAX_HEALTH_ATTEMPTS); do
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
        echo "  Health check passed (attempt ${i}/${MAX_HEALTH_ATTEMPTS})"
        HEALTHY=true
        break
    fi
    echo "  Waiting... (attempt ${i}/${MAX_HEALTH_ATTEMPTS})"
    sleep $HEALTH_INTERVAL
done

if [ "$HEALTHY" = false ]; then
    echo ""
    echo "ERROR: Health check failed after ${MAX_HEALTH_ATTEMPTS} attempts!" >&2
    echo "Starting auto-rollback..."

    # Rollback: restore DB backup
    LATEST_BACKUP=$(ls -t "${BACKUP_DIR}"/pre_deploy_*.dump 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        echo "  Restoring database from ${LATEST_BACKUP}..."
        docker compose exec -T postgres pg_restore -U stockpulse -d stockpulse_production --clean --if-exists \
            < "$LATEST_BACKUP" 2>/dev/null || echo "  WARN: Restore had warnings"
    fi

    # Restart previous containers
    docker compose down
    docker compose up -d

    echo "Rollback complete. Please investigate the failure."
    exit 1
fi

# --- Cleanup ---
echo ""
echo "Cleaning up old backups (keeping last 7)..."
ls -t "${BACKUP_DIR}"/pre_deploy_*.dump 2>/dev/null | tail -n +8 | xargs -r rm -f

echo "Pruning unused Docker images..."
docker image prune -f > /dev/null 2>&1

echo ""
echo "=== Deploy Complete ==="
echo "Environment: ${ENVIRONMENT}"
echo "Time: $(date)"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
