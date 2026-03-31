#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="${DB_NAME:-stockpulse_production}"

echo "=== StockPulse Backup ==="

mkdir -p "$BACKUP_DIR"

echo "Backing up database..."
docker compose exec -T postgres pg_dump -U stockpulse "$DB_NAME" | gzip > "$BACKUP_DIR/db_${TIMESTAMP}.sql.gz"

echo "Cleaning old backups (keeping last 30)..."
ls -t "$BACKUP_DIR"/db_*.sql.gz | tail -n +31 | xargs -r rm

echo "Backup complete: $BACKUP_DIR/db_${TIMESTAMP}.sql.gz"
