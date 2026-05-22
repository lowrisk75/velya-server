#!/bin/bash
set -euo pipefail

# Velya Server - Proxmox LXC Test Script
# Usage: ./test-proxmox.sh [lxc_id]

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

LXC_ID=${1:-300}
PVE_HOST=${PVE_HOST:-10.9.8.8}

echo -e "${BOLD}${BLUE}Velya Server - Test Proxmox LXC${NC}\n"

# Check if running on PVE host
if ! command -v pct &> /dev/null; then
    echo -e "${RED}❌ Ce script doit être exécuté sur le host Proxmox${NC}"
    echo "Ou utilisez: ssh root@$PVE_HOST 'bash -s' < test-proxmox.sh $LXC_ID"
    exit 1
fi

echo -e "${BLUE}[1/6]${NC} Création du container LXC $LXC_ID..."

# Check if container exists
if pct status $LXC_ID &> /dev/null; then
    echo -e "${RED}❌ Container $LXC_ID existe déjà${NC}"
    read -p "Supprimer et recréer? (y/N): " RECREATE
    if [ "$RECREATE" = "y" ]; then
        pct stop $LXC_ID || true
        pct destroy $LXC_ID
    else
        echo "Test annulé"
        exit 1
    fi
fi

# Create LXC
pct create $LXC_ID local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname velya-server-test \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --unprivileged 1 \
  --features nesting=1

echo -e "${GREEN}✓ Container créé${NC}"

# Start container
echo -e "\n${BLUE}[2/6]${NC} Démarrage du container..."
pct start $LXC_ID

# Wait for network
sleep 10

# Get IP
LXC_IP=$(pct exec $LXC_ID -- hostname -I | awk '{print $1}')
echo -e "${GREEN}✓ Container démarré : $LXC_IP${NC}"

# Install dependencies
echo -e "\n${BLUE}[3/6]${NC} Installation des dépendances..."

pct exec $LXC_ID -- bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl git ca-certificates gnupg lsb-release

# Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl start docker
EOF

echo -e "${GREEN}✓ Docker installé${NC}"

# Clone and deploy
echo -e "\n${BLUE}[4/6]${NC} Déploiement de Velya Server..."

pct exec $LXC_ID -- bash << 'EOF'
cd /opt
git clone https://github.com/lorislabapp/velya-server.git velya-server || git clone /tmp/velya-server velya-server
cd velya-server

# Generate secrets
export SECRET_KEY=$(openssl rand -hex 32)
export DB_PASSWORD=$(openssl rand -hex 16)

cat > .env << ENV_EOF
SECRET_KEY=$SECRET_KEY
DB_PASSWORD=$DB_PASSWORD
DOMAIN=localhost
ENV_EOF

# Start services
docker compose up -d

# Wait for API
echo "Waiting for API to start..."
for i in {1..30}; do
    if curl -f http://localhost:8000/health &> /dev/null; then
        echo "✓ API started"
        break
    fi
    sleep 2
done
EOF

echo -e "${GREEN}✓ Services démarrés${NC}"

# Create test user
echo -e "\n${BLUE}[5/6]${NC} Création du compte test..."

pct exec $LXC_ID -- bash << 'EOF'
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@lorislab.fr","password":"testpassword123"}' &> /dev/null

if [ $? -eq 0 ]; then
    echo "✓ User created: test@lorislab.fr / testpassword123"
fi
EOF

echo -e "${GREEN}✓ Compte créé${NC}"

# Run tests
echo -e "\n${BLUE}[6/6]${NC} Tests..."

TEST_RESULTS=()

# Test 1: Health check
if pct exec $LXC_ID -- curl -f http://localhost:8000/health &> /dev/null; then
    echo -e "${GREEN}✓ Health check OK${NC}"
    TEST_RESULTS+=("PASS")
else
    echo -e "${RED}✗ Health check FAILED${NC}"
    TEST_RESULTS+=("FAIL")
fi

# Test 2: Login
LOGIN_RESPONSE=$(pct exec $LXC_ID -- bash << 'EOF'
curl -s -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=test@lorislab.fr&password=testpassword123"
EOF
)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✓ Login OK${NC}"
    TEST_RESULTS+=("PASS")
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
else
    echo -e "${RED}✗ Login FAILED${NC}"
    TEST_RESULTS+=("FAIL")
    TOKEN=""
fi

# Test 3: Create alarm
if [ -n "$TOKEN" ]; then
    CREATE_RESPONSE=$(pct exec $LXC_ID -- bash << EOF
curl -s -X POST http://localhost:8000/api/alarms \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"client_id":"test-alarm-1","time":"07:30:00","label":"Test Alarm","is_enabled":true,"sound":"default","repeat_days":[1,2,3,4,5],"snooze_interval":600,"vibration":true}'
EOF
)

    if echo "$CREATE_RESPONSE" | grep -q '"id"'; then
        echo -e "${GREEN}✓ Create alarm OK${NC}"
        TEST_RESULTS+=("PASS")
    else
        echo -e "${RED}✗ Create alarm FAILED${NC}"
        TEST_RESULTS+=("FAIL")
    fi
fi

# Test 4: List alarms
if [ -n "$TOKEN" ]; then
    LIST_RESPONSE=$(pct exec $LXC_ID -- bash << EOF
curl -s -X GET http://localhost:8000/api/alarms \
  -H "Authorization: Bearer $TOKEN"
EOF
)

    if echo "$LIST_RESPONSE" | grep -q "test-alarm-1"; then
        echo -e "${GREEN}✓ List alarms OK${NC}"
        TEST_RESULTS+=("PASS")
    else
        echo -e "${RED}✗ List alarms FAILED${NC}"
        TEST_RESULTS+=("FAIL")
    fi
fi

# Test 5: Stats API
if [ -n "$TOKEN" ]; then
    STATS_RESPONSE=$(pct exec $LXC_ID -- bash << EOF
curl -s -X GET http://localhost:8000/api/stats/alarms \
  -H "Authorization: Bearer $TOKEN"
EOF
)

    if echo "$STATS_RESPONSE" | grep -q "total_alarms"; then
        echo -e "${GREEN}✓ Stats API OK${NC}"
        TEST_RESULTS+=("PASS")
    else
        echo -e "${RED}✗ Stats API FAILED${NC}"
        TEST_RESULTS+=("FAIL")
    fi
fi

# Summary
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Test Summary${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

PASS_COUNT=0
FAIL_COUNT=0
for result in "${TEST_RESULTS[@]}"; do
    if [ "$result" = "PASS" ]; then
        ((PASS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
done

echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo -e "\n${BOLD}Container Info:${NC}"
echo -e "  ID  : $LXC_ID"
echo -e "  IP  : $LXC_IP"
echo -e "  URL : http://$LXC_IP"
echo -e "\n${BOLD}Credentials:${NC}"
echo -e "  Email    : test@lorislab.fr"
echo -e "  Password : testpassword123"

echo -e "\n${BOLD}Commands:${NC}"
echo -e "  SSH       : pct enter $LXC_ID"
echo -e "  Logs      : pct exec $LXC_ID -- docker compose -f /opt/velya-server/docker-compose.yml logs -f"
echo -e "  Stop      : pct stop $LXC_ID"
echo -e "  Destroy   : pct destroy $LXC_ID"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "\n${BOLD}${GREEN}✅ Tous les tests passent !${NC}\n"
    exit 0
else
    echo -e "\n${BOLD}${RED}❌ Certains tests ont échoué${NC}\n"
    exit 1
fi
