#!/bin/bash
set -euo pipefail

# Velya Server - Complete Setup Script
# This script does EVERYTHING automatically

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}"
cat << "EOF"
__     __   _
\ \   / /__| |_   _  __ _
 \ \ / / _ \ | | | |/ _` |
  \ V /  __/ | |_| | (_| |
   \_/ \___|_|\__, |\__,_|
              |___/
   Complete Setup Script
EOF
echo -e "${NC}\n"

GITHUB_USER="lowrisk75"
GITHUB_REPO="velya-server"
PROXMOX_HOST="10.9.8.8"
LXC_ID="300"

# ============================================================================
# PHASE 1: GitHub Setup
# ============================================================================

echo -e "${BOLD}${BLUE}[PHASE 1/7]${NC} GitHub Setup\n"

# Check if repo exists
if ! git remote get-url origin &> /dev/null; then
    echo -e "${YELLOW}⚠️  Git remote 'origin' not configured${NC}"
    echo "Creating GitHub repository..."
    echo ""
    echo -e "${BOLD}Action Required:${NC}"
    echo "1. Go to: ${BLUE}https://github.com/new${NC}"
    echo "2. Repository name: ${BOLD}velya-server${NC}"
    echo "3. Description: Self-hosted alarm server for Velya iOS app"
    echo "4. Public repository"
    echo "5. Do NOT initialize (we have files already)"
    echo "6. Click 'Create repository'"
    echo ""
    read -p "Press ENTER when repository is created..."

    echo "Adding remote..."
    git remote add origin "https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
fi

echo "Pushing to GitHub..."
if git push -u origin main; then
    echo -e "${GREEN}✓ Code pushed to GitHub${NC}"
else
    echo -e "${RED}❌ Push failed. Check your GitHub credentials${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo ""
echo -e "${BOLD}GitHub Actions Status:${NC}"
echo "→ Build starting at: ${BLUE}https://github.com/${GITHUB_USER}/${GITHUB_REPO}/actions${NC}"
echo "→ Wait ~10 minutes for Docker image build"
echo ""
read -p "Press ENTER when GitHub Actions build is complete (check URL above)..."

echo ""
echo -e "${BOLD}Make Docker image public:${NC}"
echo "1. Go to: ${BLUE}https://github.com/${GITHUB_USER}/${GITHUB_REPO}/pkgs/container/${GITHUB_REPO}${NC}"
echo "2. Package settings → Change visibility → Public"
echo ""
read -p "Press ENTER when image is public..."

echo -e "${GREEN}✓ Phase 1 complete${NC}\n"

# ============================================================================
# PHASE 2: Local Docker Test
# ============================================================================

echo -e "${BOLD}${BLUE}[PHASE 2/7]${NC} Local Docker Test\n"

# Generate secrets
if [ ! -f .env ]; then
    echo "Generating secrets..."
    cat > .env << ENV_EOF
SECRET_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 16)
DOMAIN=localhost
ENV_EOF
    echo -e "${GREEN}✓ Secrets generated${NC}"
fi

# Start services
echo "Starting Docker Compose..."
docker-compose down -v &> /dev/null || true
docker-compose up -d

# Wait for health
echo "Waiting for API to start..."
for i in {1..30}; do
    if curl -f http://localhost:8000/health &> /dev/null; then
        echo -e "${GREEN}✓ API healthy${NC}"
        break
    fi
    sleep 2
done

# Create test account
echo "Creating test account..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"mail@kevinn.ie","password":"test123"}')

if echo "$REGISTER_RESPONSE" | grep -q "email"; then
    echo -e "${GREEN}✓ Account created: mail@kevinn.ie / test123${NC}"
else
    echo -e "${YELLOW}⚠️  Account might already exist${NC}"
fi

# Login and get token
echo "Testing login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=mail@kevinn.ie&password=test123")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    echo -e "${GREEN}✓ Login successful${NC}"

    # Create test alarm
    echo "Creating test alarm..."
    curl -s -X POST http://localhost:8000/api/alarms \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "client_id":"test-1",
        "time":"07:30:00",
        "label":"Morning Alarm",
        "is_enabled":true,
        "sound":"default",
        "repeat_days":[1,2,3,4,5],
        "snooze_interval":600,
        "vibration":true
      }' &> /dev/null

    echo -e "${GREEN}✓ Test alarm created${NC}"
else
    echo -e "${RED}❌ Login failed${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}Local Test Results:${NC}"
echo "→ API: ${GREEN}http://localhost:8000${NC}"
echo "→ Dashboard: ${GREEN}http://localhost${NC}"
echo "→ Credentials: mail@kevinn.ie / test123"
echo ""
echo "Opening dashboard..."
open http://localhost &> /dev/null || xdg-open http://localhost &> /dev/null || true

read -p "Verify dashboard works, then press ENTER to continue..."

echo -e "${GREEN}✓ Phase 2 complete${NC}\n"

# ============================================================================
# PHASE 3: Proxmox LXC Test
# ============================================================================

echo -e "${BOLD}${BLUE}[PHASE 3/7]${NC} Proxmox LXC Deployment\n"

# Check SSH access
if ! ssh -o ConnectTimeout=5 root@${PROXMOX_HOST} "echo test" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Cannot SSH to Proxmox host${NC}"
    echo "Setup SSH key:"
    echo "  ssh-copy-id root@${PROXMOX_HOST}"
    echo ""
    read -p "Press ENTER when SSH access is configured, or SKIP to skip Proxmox test: " SKIP_PVE

    if [ "$SKIP_PVE" = "SKIP" ]; then
        echo -e "${YELLOW}⊘ Skipping Proxmox test${NC}\n"
        SKIP_PROXMOX=true
    fi
fi

if [ "${SKIP_PROXMOX:-false}" != "true" ]; then
    echo "Copying test script to Proxmox..."
    scp test-proxmox.sh root@${PROXMOX_HOST}:/tmp/

    echo "Running automated test on Proxmox..."
    echo ""
    ssh root@${PROXMOX_HOST} "cd /tmp && chmod +x test-proxmox.sh && ./test-proxmox.sh ${LXC_ID}"

    # Get LXC IP
    LXC_IP=$(ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- hostname -I | awk '{print \$1}'")

    echo ""
    echo -e "${BOLD}Proxmox LXC Info:${NC}"
    echo "→ Container: ${LXC_ID}"
    echo "→ IP: ${LXC_IP}"
    echo "→ URL: ${GREEN}http://${LXC_IP}${NC}"
    echo "→ Credentials: test@lorislab.fr / testpassword123"
    echo ""

    echo -e "${GREEN}✓ Phase 3 complete${NC}\n"
fi

# ============================================================================
# PHASE 4: Cloudflare Tunnel
# ============================================================================

echo -e "${BOLD}${BLUE}[PHASE 4/7]${NC} Cloudflare Tunnel Setup\n"

if [ "${SKIP_PROXMOX:-false}" != "true" ]; then
    echo "Setting up Cloudflare Tunnel on LXC ${LXC_ID}..."

    ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- bash" << 'TUNNEL_EOF'
# Install cloudflared
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb
fi

echo "Cloudflared installed"
TUNNEL_EOF

    echo ""
    echo -e "${BOLD}Manual Steps Required:${NC}"
    echo "SSH into LXC and run:"
    echo ""
    echo -e "${BLUE}pct enter ${LXC_ID}${NC}"
    echo ""
    echo "Then inside LXC:"
    echo -e "${BLUE}cloudflared tunnel login${NC}"
    echo -e "${BLUE}cloudflared tunnel create velya-server${NC}"
    echo ""
    echo "Create config:"
    cat << 'CONFIG_EOF'
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml << EOF
tunnel: velya-server
credentials-file: /root/.cloudflared/TUNNEL_ID.json

ingress:
  - hostname: velya.kevinn.ie
    service: http://localhost:80
  - service: http_status:404
EOF
CONFIG_EOF
    echo ""
    echo "Route DNS and start service:"
    echo -e "${BLUE}cloudflared tunnel route dns velya-server velya.kevinn.ie${NC}"
    echo -e "${BLUE}cloudflared service install${NC}"
    echo -e "${BLUE}systemctl start cloudflared${NC}"
    echo ""
    read -p "Press ENTER when Cloudflare Tunnel is configured..."

    echo -e "${GREEN}✓ Phase 4 complete${NC}\n"
else
    echo -e "${YELLOW}⊘ Skipping (no LXC)${NC}\n"
fi

# ============================================================================
# PHASE 5: Blog Post
# ============================================================================

echo -e "${BOLD}${BLUE}[PHASE 5/7]${NC} Blog Post Publication\n"

echo "Blog article is ready at: BLOG_POST.md"
echo ""
echo -e "${BOLD}Manual Steps:${NC}"
echo "1. Copy content:"
echo -e "   ${BLUE}pbcopy < BLOG_POST.md${NC}"
echo ""
echo "2. Convert Markdown to HTML:"
echo "   → Use: https://markdowntohtml.com/"
echo ""
echo "3. Create page on lorislab.fr:"
echo "   → /blog/velya-self-hosted.html"
echo ""
echo "4. Add SEO meta tags (see GETTING_STARTED.md)"
echo ""
echo "5. Publish"
echo ""
read -p "Press ENTER when blog post is published..."

echo -e "${GREEN}✓ Phase 5 complete${NC}\n"

# ============================================================================
# PHASE 6: Social Sharing
# ============================================================================

echo -e "${BOLD}${BLUE}[PHASE 6/7]${NC} Social Media Sharing\n"

echo "Sharing on social media..."
echo ""

# Reddit post template
cat > /tmp/reddit-selfhosted.txt << 'REDDIT_EOF'
Title: Self-hosted alarm server for iOS with Home Assistant integration

I built Velya Server - a self-hosted backend for my iOS alarm app.

Features:
• Web dashboard (timeline, stats, CRUD)
• Home Assistant webhooks (vacation mode, weather-based wake time)
• Real-time sync across devices
• Docker one-liner install
• Open source (MIT)

Tech stack: FastAPI, PostgreSQL, Redis, Svelte 5

5-minute setup on Raspberry Pi, Synology NAS, or any Docker host.

GitHub: https://github.com/lowrisk75/velya-server

Happy to answer questions!
REDDIT_EOF

cat > /tmp/reddit-homeassistant.txt << 'REDDIT_HA_EOF'
Title: Control your iPhone alarms from Home Assistant

Built a bridge between iOS alarms and Home Assistant.

Use cases:
• Vacation mode → disable all morning alarms
• Snow forecast → wake 30min earlier
• Calendar meeting at 8am → advance alarm automatically
• Sleep score < 70 → skip alarm, let me sleep in

Self-hosted (Raspberry Pi, NAS, VPS). 5-min Docker setup.

Example automation:
```yaml
automation:
  - alias: "Vacation - Disable Alarms"
    trigger:
      platform: state
      entity_id: input_boolean.vacation_mode
      to: "on"
    action:
      service: rest_command.velya_disable_alarm
```

GitHub: https://github.com/lowrisk75/velya-server

AMA!
REDDIT_HA_EOF

cat > /tmp/twitter-thread.txt << 'TWITTER_EOF'
Just open-sourced Velya Server 🎉

Self-hosted alarm management for iOS:
• Privacy-first (your data stays home)
• Docker one-liner install
• Home Assistant integration
• Web dashboard
• Zero cost, zero tracking

github.com/lowrisk75/velya-server

🧵 Thread on why I built this...

1/ Most "smart" alarm apps force you into their cloud:
- $10/mo subscriptions
- Data mining
- Internet dependency
- No control

I wanted the opposite: 100% local by default, optional self-hosting for power users.

2/ The server runs on anything:
- Raspberry Pi 4 (2GB)
- Synology/QNAP NAS
- VPS ($5/mo)
- LXC on Proxmox

5-minute Docker Compose setup. That's it.

3/ Home Assistant integration example:

When vacation mode activates → disable all alarms
When snow forecast → wake 30min earlier
When bad sleep score → let me sleep in

All via simple REST webhooks.

4/ Privacy architecture:
✅ Your server, your data
✅ No telemetry, no tracking
✅ Open source (MIT) - audit the code
✅ Works 100% offline (local network)

5/ Tech stack for the nerds:
Backend: FastAPI + PostgreSQL + Redis
Frontend: Svelte 5 + TailwindCSS
Sync: Last-write-wins with event sourcing
Auth: JWT (30-day tokens)

6/ What's next:
- Apple Shortcuts integration
- Siri voice commands
- Sleep tracking (Apple Health, Oura)
- Smart wake windows
- Android app (React Native)

Feedback welcome! 🙏
TWITTER_EOF

echo "Post templates created:"
echo "→ ${BLUE}/tmp/reddit-selfhosted.txt${NC}"
echo "→ ${BLUE}/tmp/reddit-homeassistant.txt${NC}"
echo "→ ${BLUE}/tmp/twitter-thread.txt${NC}"
echo ""
echo -e "${BOLD}Post to:${NC}"
echo "• Reddit r/selfhosted"
echo "• Reddit r/homeassistant"
echo "• Twitter/X"
echo "• Hacker News (Show HN)"
echo ""

read -p "Press ENTER when posted..."

echo -e "${GREEN}✓ Phase 6 complete${NC}\n"

# ============================================================================
# PHASE 7: Final Summary
# ============================================================================

echo -e "${BOLD}${BLUE}[PHASE 7/7]${NC} Setup Complete! 🎉\n"

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✅ Velya Server - Live!${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${BOLD}🌐 URLs:${NC}"
echo "→ GitHub: ${BLUE}https://github.com/${GITHUB_USER}/${GITHUB_REPO}${NC}"
echo "→ Docker Image: ${BLUE}ghcr.io/${GITHUB_USER}/${GITHUB_REPO}:latest${NC}"

if [ "${SKIP_PROXMOX:-false}" != "true" ]; then
    echo "→ Production: ${BLUE}https://velya.kevinn.ie${NC}"
    echo "→ Local LXC: ${BLUE}http://${LXC_IP}${NC}"
fi

echo ""
echo -e "${BOLD}📱 Next: iOS App Integration${NC}"
echo "Add Remote Server toggle in Settings"
echo "See: GETTING_STARTED.md Phase 5"

echo ""
echo -e "${BOLD}📊 Stats to Track:${NC}"
echo "• GitHub stars"
echo "• Reddit upvotes"
echo "• Docker pulls"
echo "• Blog traffic"

echo ""
echo -e "${BOLD}🎯 Success Metrics (Week 1):${NC}"
echo "• 50-200 GitHub stars"
echo "• 100-500 Reddit upvotes"
echo "• 500-1000 Docker pulls"
echo "• Featured on r/selfhosted hot"

echo ""
echo -e "${GREEN}Everything is ready to go! 🚀${NC}\n"

# Clean up test account
echo "Cleaning up local test..."
docker-compose down -v &> /dev/null || true

echo -e "${BOLD}Setup script complete!${NC}\n"
