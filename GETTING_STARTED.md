# Getting Started - Velya Server

Guide complet pour publier et tester Velya Server.

## Phase 1: Publication GitHub (5 min)

### 1. Créer le Repository

```bash
# Sur GitHub.com
# 1. Aller sur https://github.com/new
# 2. Nom: velya-server
# 3. Description: Self-hosted alarm server for Velya iOS app
# 4. Public
# 5. Ne PAS initialiser avec README (on a déjà les fichiers)
# 6. Create repository
```

### 2. Push le Code

```bash
cd /Users/kevinnadjarian/GitHub/velya-server

# Ajouter remote
git remote add origin https://github.com/lowrisk75/velya-server.git

# Push
git push -u origin main
```

### 3. Configurer GitHub Container Registry

Les GitHub Actions vont automatiquement build et push l'image Docker vers `ghcr.io/lowrisk75/velya-server:latest` dès le premier push.

**Vérifier après push:**
- Actions tab → "Docker Build & Push" doit être en cours
- Après ~5-10 min → image disponible sur `ghcr.io`

### 4. Rendre l'Image Publique

```
# Sur GitHub
1. Aller sur le package: https://github.com/lowrisk75/velya-server/pkgs/container/velya-server
2. Package settings → Change visibility → Public
3. Confirm
```

---

## Phase 2: Test Local (Docker Desktop)

### 1. Build Local

```bash
cd /Users/kevinnadjarian/GitHub/velya-server

# Build
docker build -t velya-server:test .

# Vérifier
docker images | grep velya-server
```

### 2. Test avec Docker Compose

```bash
# Créer .env
cat > .env << EOF
SECRET_KEY=$(openssl rand -hex 32)
DB_PASSWORD=$(openssl rand -hex 16)
DOMAIN=localhost
EOF

# Start
docker-compose up -d

# Vérifier
docker-compose ps
docker-compose logs -f velya-api

# Test health
curl http://localhost:8000/health
# Attendu: {"status":"ok"}

# Test frontend
open http://localhost
```

### 3. Créer un Compte et Tester

```bash
# Register
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"mail@kevinn.ie","password":"test123"}'

# Login
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=mail@kevinn.ie&password=test123"

# Copier le access_token retourné
export TOKEN="<paste-token-here>"

# Créer une alarme
curl -X POST http://localhost:8000/api/alarms \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_id":"test-1",
    "time":"07:30:00",
    "label":"Test Alarm",
    "is_enabled":true,
    "sound":"default",
    "repeat_days":[1,2,3,4,5],
    "snooze_interval":600,
    "vibration":true
  }'

# Lister les alarmes
curl -X GET http://localhost:8000/api/alarms \
  -H "Authorization: Bearer $TOKEN"

# Stats
curl -X GET http://localhost:8000/api/stats/alarms \
  -H "Authorization: Bearer $TOKEN"

# Timeline
curl -X GET "http://localhost:8000/api/stats/timeline?days=7" \
  -H "Authorization: Bearer $TOKEN"
```

### 4. Clean Up

```bash
docker-compose down -v
```

---

## Phase 3: Test Proxmox LXC (Production-like)

### Méthode A: Script Automatique

```bash
# Sur ton Mac
scp test-proxmox.sh root@10.9.8.8:/tmp/

# Sur Proxmox host
ssh root@10.9.8.8
cd /tmp
chmod +x test-proxmox.sh
./test-proxmox.sh 300

# Le script va:
# 1. Créer LXC 300
# 2. Installer Docker
# 3. Déployer Velya
# 4. Créer compte test
# 5. Lancer 5 tests automatiques
# 6. Afficher résumé + credentials
```

### Méthode B: Manuel (plus de contrôle)

```bash
# Sur Proxmox host
ssh root@10.9.8.8

# Créer LXC
pct create 300 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname velya-server \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --unprivileged 1 \
  --features nesting=1

# Start
pct start 300

# Enter
pct enter 300
```

**Dans le LXC:**

```bash
# Update
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | bash

# Clone repo
cd /opt
git clone https://github.com/lowrisk75/velya-server.git
cd velya-server

# Deploy
chmod +x deployment/deploy.sh
./deployment/deploy.sh
```

### Vérifier le Déploiement

```bash
# Services status
systemctl status velya-api
docker ps

# Logs
journalctl -u velya-api -f

# Test
curl http://localhost:8000/health

# Get LXC IP
hostname -I
# → Note l'IP (ex: 10.9.8.123)

# Test depuis ton Mac
curl http://10.9.8.123:8000/health
open http://10.9.8.123
```

---

## Phase 4: Cloudflare Tunnel (Accès Public)

### 1. Installer cloudflared

**Dans le LXC:**

```bash
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb
```

### 2. Authentifier

```bash
cloudflared tunnel login
# → Ouvre un navigateur, connecte-toi à Cloudflare
```

### 3. Créer le Tunnel

```bash
cloudflared tunnel create velya-server

# Note le Tunnel ID (ex: 12345678-1234-1234-1234-123456789abc)
```

### 4. Configurer

```bash
mkdir -p ~/.cloudflared

cat > ~/.cloudflared/config.yml << EOF
tunnel: velya-server
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

ingress:
  - hostname: velya.kevinn.ie
    service: http://localhost:80
  - service: http_status:404
EOF
```

### 5. Router DNS

```bash
cloudflared tunnel route dns velya-server velya.kevinn.ie
```

### 6. Démarrer comme Service

```bash
cloudflared service install
systemctl start cloudflared
systemctl enable cloudflared

# Vérifier
systemctl status cloudflared
```

### 7. Tester

```bash
# Depuis ton Mac
curl https://velya.kevinn.ie/api/health
open https://velya.kevinn.ie
```

---

## Phase 5: App iOS Integration

### 1. Ajouter Settings Remote Server

**Dans Velya iOS (Settings.swift ou SettingsView.swift):**

```swift
Section {
    Toggle("Remote Server", isOn: $settings.remoteServerEnabled)
    
    if settings.remoteServerEnabled {
        TextField("Server URL", text: $settings.serverURL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
        
        if !settings.serverURL.isEmpty {
            Button("Test Connection") {
                Task {
                    await testConnection()
                }
            }
        }
    }
} header: {
    Text("Remote Management")
} footer: {
    if settings.remoteServerEnabled {
        Text("Self-hosting required. See github.com/lowrisk75/velya-server for installation guide.")
    }
}
```

### 2. API Client

```swift
// Velya/Core/RemoteAPI.swift
actor RemoteAPIClient {
    let baseURL: URL
    var token: String?
    
    init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    func login(email: String, password: String) async throws {
        // POST /api/auth/login
        // Store token
    }
    
    func syncPush(alarms: [Alarm]) async throws {
        // POST /api/sync/push
    }
    
    func syncPull(since: Date) async throws -> [AlarmUpdate] {
        // GET /api/sync/pull?since={timestamp}
    }
}
```

### 3. Sync Logic

```swift
// Velya/Core/SyncManager.swift
@Observable
class SyncManager {
    var isEnabled: Bool = false
    var serverURL: String = ""
    var lastSync: Date?
    
    private var api: RemoteAPIClient?
    
    func sync() async throws {
        guard isEnabled, let api else { return }
        
        // 1. Push local changes
        let localChanges = getLocalChanges()
        try await api.syncPush(alarms: localChanges)
        
        // 2. Pull remote changes
        let remoteChanges = try await api.syncPull(since: lastSync ?? .distantPast)
        applyRemoteChanges(remoteChanges)
        
        lastSync = .now
    }
}
```

---

## Phase 6: Publier Blog Article

### Sur lorislab.fr

```bash
# Copier le contenu de BLOG_POST.md
pbcopy < BLOG_POST.md

# Créer page blog
# 1. Aller sur lorislab.fr admin (ou éditeur HTML)
# 2. Créer nouvelle page: /blog/velya-self-hosted.html
# 3. Coller le contenu (converti en HTML)
# 4. Ajouter meta tags:

<meta name="description" content="Hébergez votre propre serveur d'alarmes avec Velya. Privacy-first, self-hosted, open source. Guide complet Docker, Proxmox, Home Assistant.">
<meta property="og:title" content="Velya Self-Hosted - Prenez le Contrôle de Vos Réveils">
<meta property="og:description" content="Guide complet pour héberger votre serveur d'alarmes. Privacy-first, zero abonnement, intégration Home Assistant.">
<meta property="og:image" content="https://lorislab.fr/assets/velya-dashboard.png">

# 5. Publier
```

### SEO

**Keywords cibles:**
- self-hosted alarm app
- privacy alarm iOS
- home assistant alarm integration
- open source alarm server
- raspberry pi alarm

### Partager

- **Reddit:** r/selfhosted, r/homeassistant, r/privacy
- **Hacker News:** Show HN: Velya - Self-Hosted Alarm Server
- **Twitter/X:** Thread avec screenshots

---

## Phase 7: App Store Metadata Update

### Description

**Ajouter section:**

```
🏠 SELF-HOSTING (OPTIONNEL)

Velya fonctionne 100% localement par défaut. Pour les utilisateurs avancés, hébergez votre propre serveur pour :

• Gérer vos alarmes depuis un navigateur web
• Intégrer avec Home Assistant, Node-RED
• Synchroniser entre plusieurs appareils
• Garder vos données chez vous

Installation: github.com/lowrisk75/velya-server
Docker, Raspberry Pi, NAS Synology compatible.
```

### Screenshots

**Ajouter:**
- Screenshot du dashboard web (timeline)
- Screenshot iOS avec "Remote Server" toggle
- Screenshot Home Assistant automation

### App Preview Video

**Séquence:**
1. App standalone (local)
2. Toggle "Remote Server"
3. Dashboard web sur iPad
4. Home Assistant automation
5. Retour iOS - alarme updated

---

## Troubleshooting

### GitHub Actions Build Échoue

**Check:**
```bash
# Vérifier les logs
# GitHub → Actions → Click sur le workflow failed
# Lire les erreurs
```

**Communs:**
- Frontend build fail → vérifier package.json dependencies
- Backend test fail → skip tests avec `--no-cache-dir`

### Docker Build Local Échoue

```bash
# Build verbose
docker build -t velya-server:test . --progress=plain --no-cache

# Si npm install fail
cd frontend
npm install
npm run build
cd ..
```

### LXC Container ne Démarre Pas

```bash
# Vérifier logs
pct status 300
journalctl -xe

# Augmenter RAM
pct set 300 --memory 4096

# Vérifier nesting
pct set 300 --features nesting=1
```

### API Health Check Fail

```bash
# Check logs
docker-compose logs velya-api

# Common issues:
# - DB connection: vérifier DATABASE_URL
# - Port conflict: lsof -i :8000
# - Missing env: vérifier .env existe
```

### Cloudflare Tunnel ne Connecte Pas

```bash
# Logs
journalctl -u cloudflared -f

# Restart
systemctl restart cloudflared

# Re-authenticate
cloudflared tunnel login
```

---

## Next Steps

Une fois tout testé et fonctionnel :

- [ ] Push GitHub ✅
- [ ] Build Docker image auto (GitHub Actions) ✅
- [ ] Test local Docker Compose
- [ ] Test Proxmox LXC
- [ ] Cloudflare Tunnel setup
- [ ] App iOS integration
- [ ] Publier blog article
- [ ] Update App Store metadata
- [ ] Share on Reddit/HN

---

**Questions ?** support@lorislab.fr
