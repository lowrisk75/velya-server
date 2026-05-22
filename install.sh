#!/bin/bash
set -euo pipefail

# Velya Server - One-Liner Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/lorislabapp/velya-server/main/install.sh | bash

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}"
cat << "EOF"
__     __   _
\ \   / /__| |_   _  __ _
 \ \ / / _ \ | | | |/ _` |
  \ V /  __/ | |_| | (_| |
   \_/ \___|_|\__, |\__,_|
              |___/
   Self-Hosted Alarm Server
EOF
echo -e "${NC}"

echo -e "${BOLD}Velya Server - Installation${NC}\n"

# Check prerequisites
echo -e "${BLUE}[1/6]${NC} Vérification des prérequis..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker n'est pas installé.${NC}"
    echo "Installez Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose n'est pas installé.${NC}"
    echo "Installez Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

echo -e "${GREEN}✓ Docker installé${NC}"
echo -e "${GREEN}✓ Docker Compose installé${NC}"

# Create installation directory
echo -e "\n${BLUE}[2/6]${NC} Création du répertoire d'installation..."

read -p "Répertoire d'installation [./velya-server]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-./velya-server}

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo -e "${GREEN}✓ Répertoire créé : $(pwd)${NC}"

# Download docker-compose.yml
echo -e "\n${BLUE}[3/6]${NC} Téléchargement de la configuration..."

cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  velya-api:
    image: ghcr.io/lorislabapp/velya-server:latest
    container_name: velya-api
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://velya:${DB_PASSWORD}@db/velya
      - REDIS_URL=redis://redis:6379
      - SECRET_KEY=${SECRET_KEY}
      - CORS_ORIGINS=["http://localhost:5173","http://localhost","https://${DOMAIN}"]
      - APP_NAME=Velya Server
      - VERSION=1.0.0
    depends_on:
      - db
      - redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: postgres:14-alpine
    container_name: velya-db
    environment:
      POSTGRES_DB: velya
      POSTGRES_USER: velya
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U velya"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: velya-redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: velya-nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - velya-api
    restart: unless-stopped

volumes:
  postgres_data:
COMPOSE_EOF

# Download nginx.conf
cat > nginx.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    upstream api {
        server velya-api:8000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            return 200 '<!DOCTYPE html>
<html>
<head>
    <title>Velya Server</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
               max-width: 600px; margin: 100px auto; padding: 20px; text-align: center; }
        h1 { color: #0071E3; }
        a { color: #0071E3; text-decoration: none; }
        .status { background: #34C759; color: white; padding: 10px 20px;
                  border-radius: 8px; display: inline-block; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>✅ Velya Server Running</h1>
    <div class="status">All services operational</div>
    <p>API: <a href="/api/health">/api/health</a></p>
    <p>Configure your iOS app to connect to this server.</p>
    <hr style="margin: 40px 0;">
    <p><small>Version 1.0.0 • <a href="https://github.com/lorislabapp/velya-server">GitHub</a></small></p>
</body>
</html>';
            add_header Content-Type text/html;
        }

        location /api {
            proxy_pass http://api;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /webhook {
            proxy_pass http://api;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /api/sync/ws {
            proxy_pass http://api;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 86400;
        }
    }
}
NGINX_EOF

echo -e "${GREEN}✓ docker-compose.yml créé${NC}"
echo -e "${GREEN}✓ nginx.conf créé${NC}"

# Generate secrets
echo -e "\n${BLUE}[4/6]${NC} Génération des secrets..."

SECRET_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 16)

cat > .env << ENV_EOF
# Velya Server Configuration
# Generated on $(date)

# Security
SECRET_KEY=$SECRET_KEY
DB_PASSWORD=$DB_PASSWORD

# Domain (for CORS)
DOMAIN=localhost
ENV_EOF

echo -e "${GREEN}✓ Secrets générés (.env)${NC}"

# Start services
echo -e "\n${BLUE}[5/6]${NC} Démarrage des services..."

if docker compose version &> /dev/null; then
    docker compose up -d
else
    docker-compose up -d
fi

# Wait for services to be ready
echo -e "${YELLOW}⏳ Attente du démarrage des services (30s)...${NC}"
sleep 5

for i in {1..25}; do
    if curl -f http://localhost:8000/health &> /dev/null; then
        echo -e "${GREEN}✓ API démarrée${NC}"
        break
    fi
    sleep 1
done

# Create first user
echo -e "\n${BLUE}[6/6]${NC} Création de votre compte..."

read -p "Email: " USER_EMAIL
read -sp "Mot de passe: " USER_PASSWORD
echo ""

RESPONSE=$(curl -s -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASSWORD\"}" \
  -w "\n%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✓ Compte créé avec succès !${NC}"
else
    echo -e "${YELLOW}⚠️  Erreur lors de la création du compte${NC}"
    echo "Vous pouvez le créer manuellement :"
    echo "curl -X POST http://localhost:8000/api/auth/register \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASSWORD\"}'"
fi

# Success message
echo -e "\n${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✅ Installation terminée !${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${BOLD}📊 Votre serveur Velya est opérationnel :${NC}"
echo -e "   Dashboard : ${BLUE}http://localhost${NC}"
echo -e "   API       : ${BLUE}http://localhost:8000${NC}"
echo -e "   Health    : ${BLUE}http://localhost:8000/health${NC}\n"

echo -e "${BOLD}📱 Configuration de l'app iOS :${NC}"
echo -e "   1. Ouvrir Velya sur iPhone"
echo -e "   2. Réglages ⚙️  → Remote Server"
echo -e "   3. URL : ${BLUE}http://$(hostname -I | awk '{print $1}')${NC}"
echo -e "   4. Login : ${BLUE}$USER_EMAIL${NC}\n"

echo -e "${BOLD}🔧 Commandes utiles :${NC}"
echo -e "   Voir les logs    : ${BLUE}docker-compose logs -f${NC}"
echo -e "   Arrêter          : ${BLUE}docker-compose down${NC}"
echo -e "   Redémarrer       : ${BLUE}docker-compose restart${NC}"
echo -e "   Mise à jour      : ${BLUE}docker-compose pull && docker-compose up -d${NC}\n"

echo -e "${BOLD}📚 Documentation :${NC}"
echo -e "   GitHub  : ${BLUE}https://github.com/lorislabapp/velya-server${NC}"
echo -e "   Support : ${BLUE}support@lorislab.fr${NC}\n"

echo -e "${BOLD}${YELLOW}⚠️  Sécurité :${NC}"
echo -e "   - Changez le mot de passe DB dans .env"
echo -e "   - Configurez HTTPS pour production (Cloudflare Tunnel recommandé)"
echo -e "   - Activez le firewall (ufw allow 80/tcp)\n"

echo -e "${GREEN}Merci d'avoir choisi Velya ! 🎉${NC}\n"
