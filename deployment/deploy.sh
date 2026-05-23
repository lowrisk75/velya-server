#!/bin/bash
set -euo pipefail

# Velya Server Deployment Script for LXC Container
# Run this script inside the LXC container

DEPLOY_USER="velya"
DEPLOY_DIR="/opt/velya-server"
REPO_URL="https://github.com/lowrisk75/velya-server.git"  # Update with actual repo

echo "=== Velya Server Deployment ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install dependencies
echo "Installing dependencies..."
apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3-pip \
    postgresql \
    postgresql-contrib \
    redis-server \
    nginx \
    git \
    curl \
    ca-certificates

# Create deployment user
if ! id "$DEPLOY_USER" &>/dev/null; then
    echo "Creating deployment user..."
    useradd -r -m -s /bin/bash "$DEPLOY_USER"
fi

# Clone repository
if [ ! -d "$DEPLOY_DIR" ]; then
    echo "Cloning repository..."
    git clone "$REPO_URL" "$DEPLOY_DIR"
    chown -R "$DEPLOY_USER:$DEPLOY_USER" "$DEPLOY_DIR"
else
    echo "Repository already exists, pulling latest..."
    cd "$DEPLOY_DIR"
    sudo -u "$DEPLOY_USER" git pull
fi

# Create Python virtual environment
echo "Setting up Python virtual environment..."
cd "$DEPLOY_DIR"
sudo -u "$DEPLOY_USER" python3.11 -m venv venv
sudo -u "$DEPLOY_USER" venv/bin/pip install --upgrade pip
sudo -u "$DEPLOY_USER" venv/bin/pip install -r backend/requirements.txt

# PostgreSQL setup
echo "Configuring PostgreSQL..."
sudo -u postgres psql <<EOF
-- Create database and user
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'velya') THEN
        CREATE DATABASE velya;
    END IF;

    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'velya') THEN
        CREATE USER velya WITH PASSWORD 'velya_password_change_me';
    END IF;

    GRANT ALL PRIVILEGES ON DATABASE velya TO velya;
END
\$\$;
EOF

# Create .env file
if [ ! -f "$DEPLOY_DIR/.env" ]; then
    echo "Creating .env file..."
    cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"

    # Generate secret key
    SECRET_KEY=$(openssl rand -hex 32)
    sed -i "s|your-secret-key-generate-with-openssl-rand-hex-32|$SECRET_KEY|g" "$DEPLOY_DIR/.env"
    sed -i "s|your_password_here|velya_password_change_me|g" "$DEPLOY_DIR/.env"

    chown "$DEPLOY_USER:$DEPLOY_USER" "$DEPLOY_DIR/.env"
    chmod 600 "$DEPLOY_DIR/.env"

    echo "⚠️  IMPORTANT: Edit $DEPLOY_DIR/.env and change the database password!"
fi

# Run database migrations (when Alembic is set up)
# echo "Running database migrations..."
# cd "$DEPLOY_DIR"
# sudo -u "$DEPLOY_USER" venv/bin/alembic upgrade head

# Install frontend dependencies
echo "Building frontend..."
cd "$DEPLOY_DIR/frontend"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
sudo -u "$DEPLOY_USER" npm install
sudo -u "$DEPLOY_USER" npm run build

# Install systemd service
echo "Installing systemd service..."
cp "$DEPLOY_DIR/deployment/velya-api.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable velya-api
systemctl start velya-api

# Configure nginx
echo "Configuring nginx..."
cp "$DEPLOY_DIR/deployment/nginx-velya.conf" /etc/nginx/sites-available/velya
ln -sf /etc/nginx/sites-available/velya /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# Configure Redis
echo "Configuring Redis..."
systemctl enable redis-server
systemctl start redis-server

# Firewall rules (if ufw is installed)
if command -v ufw &> /dev/null; then
    echo "Configuring firewall..."
    ufw allow 80/tcp
    ufw allow 443/tcp
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Backend API: http://localhost:8000"
echo "Frontend: http://localhost"
echo ""
echo "Next steps:"
echo "1. Edit $DEPLOY_DIR/.env and change passwords"
echo "2. Set up Cloudflare Tunnel for public access"
echo "3. Create first user account via API"
echo "4. Configure iOS app to connect to server"
echo ""
echo "Service status:"
systemctl status velya-api --no-pager -l
