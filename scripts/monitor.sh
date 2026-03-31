#!/usr/bin/env bash
set -euo pipefail

# StockPulse Health Monitor
# Run every 5 minutes via cron:
#   */5 * * * * cd /home/stockpulse/app && bash scripts/monitor.sh >> log/monitor.log 2>&1

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HEALTH_URL="http://localhost:3000/api/v1/health"
TELEGRAM_ADMIN_CHAT_ID="${TELEGRAM_ADMIN_CHAT_ID:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
DISK_THRESHOLD=85

cd "$APP_DIR"

send_alert() {
    local message="$1"
    echo "[ALERT] $(date): ${message}"

    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_ADMIN_CHAT_ID" ]; then
        curl -sf -X POST \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_ADMIN_CHAT_ID}" \
            -d "text=🚨 StockPulse Monitor: ${message}" \
            -d "parse_mode=HTML" \
            > /dev/null 2>&1 || echo "  WARN: Failed to send Telegram alert"
    fi
}

# --- Health Check ---
echo "[$(date)] Running health check..."

HEALTH_OK=false
HEALTH_RESPONSE=$(curl -sf -w "\n%{http_code}" "$HEALTH_URL" 2>/dev/null) || true
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -1)

if [ "$HTTP_CODE" = "200" ]; then
    HEALTH_OK=true
    echo "  App healthy (HTTP 200)"
else
    echo "  App unhealthy (HTTP ${HTTP_CODE:-timeout}), restarting..."
    docker compose restart app
    sleep 15

    # Recheck
    HTTP_CODE_RETRY=$(curl -sf -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null) || true
    if [ "$HTTP_CODE_RETRY" = "200" ]; then
        echo "  App recovered after restart"
        send_alert "App was unhealthy, recovered after automatic restart"
    else
        send_alert "App unhealthy and restart failed! HTTP: ${HTTP_CODE_RETRY:-timeout}. Manual intervention required."
    fi
fi

# --- Disk Usage ---
DISK_USAGE=$(df / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    send_alert "Disk usage at ${DISK_USAGE}% (threshold: ${DISK_THRESHOLD}%)"
fi

# --- Container Status ---
STOPPED=$(docker compose ps --status exited -q 2>/dev/null | wc -l | tr -d ' ')
if [ "$STOPPED" -gt 0 ]; then
    STOPPED_NAMES=$(docker compose ps --status exited --format "{{.Name}}" 2>/dev/null | tr '\n' ', ')
    send_alert "Stopped containers detected: ${STOPPED_NAMES}"
fi

echo "[$(date)] Monitor complete"
