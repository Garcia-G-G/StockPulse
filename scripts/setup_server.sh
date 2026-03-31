#!/usr/bin/env bash
set -euo pipefail

# StockPulse Server Setup — Hetzner CX22 (Ubuntu 22.04/24.04)
# Run as root on fresh server: bash scripts/setup_server.sh

echo "=== StockPulse Server Setup ==="
echo "Target: Hetzner CX22 (2 vCPU, 4 GB RAM, 40 GB SSD)"

# --- System Update ---
echo "[1/10] Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release \
    git htop tmux ufw fail2ban unzip jq

# --- Docker CE ---
echo "[2/10] Installing Docker CE..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# --- App User ---
echo "[3/10] Creating stockpulse user..."
groupadd --system stockpulse 2>/dev/null || true
useradd --system --gid stockpulse --create-home --shell /bin/bash stockpulse 2>/dev/null || true
usermod -aG docker stockpulse

# --- Directories ---
echo "[4/10] Creating directories..."
mkdir -p /home/stockpulse/app /home/stockpulse/backups
chown -R stockpulse:stockpulse /home/stockpulse

# --- Firewall (UFW) ---
echo "[5/10] Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH"
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
echo "y" | ufw enable

# --- Fail2Ban ---
echo "[6/10] Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'FAIL2BAN'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
FAIL2BAN
systemctl enable fail2ban
systemctl restart fail2ban

# --- SSH Hardening ---
echo "[7/10] Hardening SSH..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# --- Swap (2 GB) ---
echo "[8/10] Creating 2 GB swap file..."
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    sysctl vm.swappiness=10
fi

# --- Backup Cron ---
echo "[9/10] Setting up daily backup cron (2 AM)..."
crontab -u stockpulse -l 2>/dev/null | grep -v "backup.sh" > /tmp/crontab_tmp || true
echo "0 2 * * * cd /home/stockpulse/app && bash scripts/backup.sh >> /home/stockpulse/backups/backup.log 2>&1" >> /tmp/crontab_tmp
crontab -u stockpulse /tmp/crontab_tmp
rm -f /tmp/crontab_tmp

# --- Log Rotation ---
echo "[10/10] Configuring log rotation..."
cat > /etc/logrotate.d/stockpulse << 'LOGROTATE'
/home/stockpulse/app/log/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
LOGROTATE

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Copy SSH pubkey to /home/stockpulse/.ssh/authorized_keys"
echo "  2. Clone repo: su - stockpulse -c 'git clone <repo> /home/stockpulse/app'"
echo "  3. Copy .env to /home/stockpulse/app/.env"
echo "  4. Run: cd /home/stockpulse/app && bash scripts/setup_ssl.sh yourdomain.com you@email.com"
echo "  5. Run: cd /home/stockpulse/app && bash scripts/deploy.sh production"
