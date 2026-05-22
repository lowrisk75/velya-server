# Velya Server - Deployment Guide

## Quick Start (LXC on Proxmox)

### 1. Create LXC Container

```bash
# On Proxmox host
pct create 300 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname velya-server \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-lvm \
  --rootfs local-lvm:8

# Start container
pct start 300
```

### 2. Deploy Application

```bash
# Enter container
pct enter 300

# Clone repository
cd /tmp
git clone <repo-url> velya-server-tmp
cd velya-server-tmp

# Run deployment script
chmod +x deployment/deploy.sh
./deployment/deploy.sh
```

The script will:
- Install all dependencies (Python, PostgreSQL, Redis, nginx, Node.js)
- Create velya user
- Set up Python virtual environment
- Configure PostgreSQL database
- Build frontend
- Install systemd service
- Configure nginx

### 3. Post-Deployment Configuration

#### Update Database Password

```bash
# Generate secure password
openssl rand -hex 32

# Update PostgreSQL
sudo -u postgres psql
ALTER USER velya WITH PASSWORD 'new_secure_password';
\q

# Update .env
nano /opt/velya-server/.env
# Change DATABASE_URL password

# Restart service
systemctl restart velya-api
```

#### Create First User

```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "mail@kevinn.ie",
    "password": "secure_password_here"
  }'
```

### 4. Cloudflare Tunnel Setup

```bash
# Install cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create velya-server

# Configure tunnel
cat > /etc/cloudflared/config.yml <<EOF
tunnel: velya-server
credentials-file: /root/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: velya.kevinn.ie
    service: http://localhost:80
  - service: http_status:404
EOF

# Install service
cloudflared service install
systemctl start cloudflared
systemctl enable cloudflared

# Route DNS
cloudflared tunnel route dns velya-server velya.kevinn.ie
```

### 5. iOS App Configuration

1. Open Velya app on iPhone
2. Go to Settings ⚙️
3. Enable "Remote Server"
4. Enter URL: `https://velya.kevinn.ie`
5. Login with credentials from step 3

## Manual Deployment (Non-LXC)

### Backend Setup

```bash
# Install Python dependencies
python3.11 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Run migrations (when available)
alembic upgrade head

# Start server
uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

### Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Development
npm run dev

# Production build
npm run build
```

### Database Setup

```bash
# PostgreSQL
sudo -u postgres psql
CREATE DATABASE velya;
CREATE USER velya WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE velya TO velya;
\q

# Redis
sudo systemctl start redis-server
```

## Monitoring

### Service Status

```bash
# API service
systemctl status velya-api

# Database
systemctl status postgresql

# Redis
systemctl status redis-server

# Nginx
systemctl status nginx

# Cloudflare Tunnel
systemctl status cloudflared
```

### Logs

```bash
# API logs
journalctl -u velya-api -f

# Nginx access logs
tail -f /var/log/nginx/access.log

# Nginx error logs
tail -f /var/log/nginx/error.log

# PostgreSQL logs
tail -f /var/log/postgresql/postgresql-14-main.log
```

### Health Checks

```bash
# API health
curl http://localhost:8000/health

# Database connection
sudo -u velya psql -d velya -c "SELECT 1;"

# Redis connection
redis-cli ping
```

## Backup

### Database Backup

```bash
# Backup
sudo -u postgres pg_dump velya > velya_backup_$(date +%Y%m%d).sql

# Restore
sudo -u postgres psql velya < velya_backup_20260523.sql
```

### Full System Backup

```bash
# On Proxmox host
vzdump 300 --mode snapshot --compress zstd --storage local
```

## Troubleshooting

### API won't start

```bash
# Check logs
journalctl -u velya-api -n 50

# Common issues:
# - Database connection: check DATABASE_URL in .env
# - Port conflict: check if 8000 is in use (lsof -i :8000)
# - Permission issues: check ownership of /opt/velya-server
```

### Frontend not loading

```bash
# Rebuild frontend
cd /opt/velya-server/frontend
sudo -u velya npm run build

# Check nginx config
nginx -t

# Check nginx logs
tail -f /var/log/nginx/error.log
```

### WebSocket connection fails

```bash
# Check nginx WebSocket config
grep -A 10 "location /api/sync/ws" /etc/nginx/sites-available/velya

# Test WebSocket (from client)
wscat -c ws://localhost:8000/api/sync/ws?token=YOUR_JWT_TOKEN
```

### Rate limit issues

```bash
# Check Redis
redis-cli
> KEYS webhook:ratelimit:*
> GET webhook:ratelimit:<webhook_id>

# Clear rate limit for testing
> DEL webhook:ratelimit:<webhook_id>
```

## Security Checklist

- [ ] Changed default database password
- [ ] Generated secure SECRET_KEY in .env
- [ ] Configured firewall (ufw/OPNsense)
- [ ] Set up Cloudflare Tunnel (SSL/TLS)
- [ ] Webhook verification codes are cryptographically secure
- [ ] PostgreSQL not exposed to public internet
- [ ] Redis not exposed to public internet
- [ ] Regular backups configured
- [ ] Monitoring/alerting set up

## Performance Tuning

### PostgreSQL

```sql
-- Add indexes for common queries
CREATE INDEX idx_alarms_user_id ON alarms(user_id);
CREATE INDEX idx_alarms_client_id ON alarms(client_id);
CREATE INDEX idx_sync_events_timestamp ON sync_events(timestamp);
CREATE INDEX idx_webhook_logs_triggered_at ON webhook_logs(triggered_at);
```

### Uvicorn Workers

```bash
# Edit systemd service
nano /etc/systemd/system/velya-api.service

# Change workers based on CPU cores
ExecStart=/opt/velya-server/venv/bin/uvicorn backend.main:app \
  --host 0.0.0.0 --port 8000 --workers 4

# Reload
systemctl daemon-reload
systemctl restart velya-api
```

### Nginx Caching

Add to nginx config:

```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=100m inactive=60m;

location /api/stats {
    proxy_cache api_cache;
    proxy_cache_valid 200 5m;
    proxy_pass http://127.0.0.1:8000;
}
```

## Updating

```bash
# Pull latest changes
cd /opt/velya-server
sudo -u velya git pull

# Update Python dependencies
sudo -u velya venv/bin/pip install -r backend/requirements.txt --upgrade

# Rebuild frontend
cd frontend
sudo -u velya npm install
sudo -u velya npm run build

# Run migrations (when available)
sudo -u velya venv/bin/alembic upgrade head

# Restart service
systemctl restart velya-api
```
