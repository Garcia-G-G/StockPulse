#!/usr/bin/env bash
set -euo pipefail

# StockPulse SSL Setup — Let's Encrypt
# Usage: bash scripts/setup_ssl.sh yourdomain.com you@email.com

DOMAIN="${1:-}"
EMAIL="${2:-}"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Usage: bash scripts/setup_ssl.sh <domain> <email>"
    echo "Example: bash scripts/setup_ssl.sh stockpulse.example.com admin@example.com"
    exit 1
fi

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP_DIR"

echo "=== StockPulse SSL Setup ==="
echo "Domain: ${DOMAIN}"
echo "Email: ${EMAIL}"

# --- Stop nginx if running (port 80 conflict) ---
docker compose stop nginx 2>/dev/null || true

# --- Get Certificate ---
echo ""
echo "Requesting certificate from Let's Encrypt..."
docker run --rm \
    -v "$(docker volume inspect stockpulse_letsencrypt_data -f '{{.Mountpoint}}' 2>/dev/null || echo '/tmp/le'):/etc/letsencrypt" \
    -v "$(docker volume inspect stockpulse_certbot_webroot -f '{{.Mountpoint}}' 2>/dev/null || echo '/tmp/cw'):/var/www/certbot" \
    -p 80:80 \
    certbot/certbot:latest \
    certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN" \
    --cert-name stockpulse

echo ""
echo "=== SSL Setup Complete ==="
echo ""
echo "Certificate location:"
echo "  Fullchain: /etc/letsencrypt/live/stockpulse/fullchain.pem"
echo "  Privkey:   /etc/letsencrypt/live/stockpulse/privkey.pem"
echo ""
echo "Next steps:"
echo "  1. Update docker/nginx/nginx.conf server_name to: ${DOMAIN}"
echo "  2. Run: docker compose up -d nginx certbot"
echo "  3. Verify: curl -I https://${DOMAIN}/api/v1/health"
