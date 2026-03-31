#!/usr/bin/env bash
set -euo pipefail

# StockPulse Database Backup
# Runs daily via cron at 2 AM

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="${APP_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="stockpulse_production"
DB_USER="stockpulse"
RETENTION_DAYS=7

cd "$APP_DIR"

echo "=== StockPulse Backup — $(date) ==="

mkdir -p "$BACKUP_DIR"

# --- Create Backup ---
BACKUP_FILE="${BACKUP_DIR}/db_${TIMESTAMP}.dump"
echo "Creating backup: ${BACKUP_FILE}"

docker compose exec -T postgres pg_dump \
    -U "$DB_USER" \
    -Fc \
    -Z 9 \
    "$DB_NAME" > "$BACKUP_FILE"

# --- Verify Backup ---
BACKUP_SIZE=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)
if [ "$BACKUP_SIZE" -lt 1000 ]; then
    echo "ERROR: Backup file too small (${BACKUP_SIZE} bytes), likely corrupt" >&2
    rm -f "$BACKUP_FILE"
    exit 1
fi

echo "Backup verified: $(numfmt --to=iec "$BACKUP_SIZE" 2>/dev/null || echo "${BACKUP_SIZE} bytes")"

# --- Cleanup Old Backups ---
echo "Cleaning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "db_*.dump" -mtime +"$RETENTION_DAYS" -delete -print | while read -r f; do
    echo "  Deleted: $(basename "$f")"
done

# --- Summary ---
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "db_*.dump" | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo ""
echo "Backup complete:"
echo "  File: $(basename "$BACKUP_FILE")"
echo "  Size: $(numfmt --to=iec "$BACKUP_SIZE" 2>/dev/null || echo "${BACKUP_SIZE} bytes")"
echo "  Total backups: ${TOTAL_BACKUPS}"
echo "  Total size: ${TOTAL_SIZE}"
