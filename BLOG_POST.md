# Prenez le Contrôle de Vos Réveils : Velya Self-Hosted

## Pourquoi héberger son propre serveur d'alarmes ?

Dans un monde où nos données personnelles sont constamment collectées et monétisées, **Velya** adopte une approche radicalement différente : vos réveils restent **100% locaux** sur votre iPhone par défaut. Mais pour ceux qui veulent aller plus loin, nous proposons une solution **self-hosted** optionnelle qui vous donne le contrôle total.

### Le problème avec les services cloud traditionnels

La plupart des apps d'alarmes modernes avec fonctionnalités "intelligentes" vous imposent :
- ☁️ Un compte cloud obligatoire
- 💰 Un abonnement mensuel ($4.99-$9.99/mois)
- 🔓 Vos données d'utilisation analysées et revendues
- 🌐 Une dépendance permanente à Internet
- 🔒 Aucun contrôle sur vos données

### L'approche Velya : Privacy-First, Self-Hosted

Avec Velya, vous choisissez :

**Mode Local (défaut, gratuit)**
- ✅ Zéro serveur requis
- ✅ Toutes vos alarmes stockées localement (SwiftData)
- ✅ Fonctionne 100% offline
- ✅ Aucune donnée ne quitte votre appareil
- ✅ Aucun compte, aucun tracking

**Mode Self-Hosted (optionnel, pour power users)**
- 🏠 Hébergez votre propre serveur (Raspberry Pi, NAS, VPS)
- 🌐 Gérez vos alarmes depuis n'importe où (web dashboard)
- 🔗 Intégrez avec Home Assistant, Node-RED, etc.
- 🔐 Vos données restent chez vous
- 🆓 Open source, gratuit, aucun coût récurrent

---

## Qu'est-ce que Velya Server ?

Velya Server est une solution **self-hosted** complète qui vous permet de :

### 📊 Dashboard Web Élégant
- Visualisez vos alarmes sur une timeline 7-30 jours
- Graphiques de distribution par heure (Chart.js)
- Statistiques détaillées (heure moyenne, alarme la plus fréquente)
- Interface Apple-like (SF Pro, TailwindCSS)

### 🔄 Synchronisation Multi-Appareils
- Sync bidirectionnel iPhone ↔ Server
- Résolution de conflits (last-write-wins)
- WebSocket temps réel (optionnel)
- Event sourcing pour traçabilité complète

### ⚡ Webhooks & Automations
- Contrôlez vos alarmes depuis Home Assistant
- Node-RED, IFTTT, Zapier compatibles
- Rate limiting intelligent (10 req/min)
- Actions : enable, disable, setTime, adjustTime

### 🔒 Sécurité & Privacy
- Authentification JWT (tokens 30 jours)
- Isolation multi-tenant (si partagé en famille)
- Rate limiting contre les abus
- Audit logging complet

---

## Installation : 5 Minutes Chrono

### Prérequis

- Un serveur Linux (Raspberry Pi 4, NAS Synology, VPS)
- Docker & Docker Compose installés
- Ports 80 et 443 disponibles

### Quick Start : One-Liner

```bash
curl -fsSL https://raw.githubusercontent.com/lowrisk75/velya-server/main/install.sh | bash
```

Cette commande :
1. Télécharge `docker-compose.yml`
2. Génère une clé secrète sécurisée
3. Configure PostgreSQL + Redis + API + Nginx
4. Démarre tous les services
5. Crée votre premier compte utilisateur

**C'est tout !** Votre serveur est opérationnel sur `http://localhost`

### Installation Manuelle (Recommandée)

#### 1. Créer `docker-compose.yml`

```yaml
version: '3.8'
services:
  velya-api:
    image: ghcr.io/lowrisk75/velya-server:latest
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://velya:changeme@db/velya
      - REDIS_URL=redis://redis:6379
      - SECRET_KEY=${SECRET_KEY}
      - CORS_ORIGINS=["http://localhost:5173","https://velya.yourdomain.com"]
    depends_on:
      - db
      - redis
    restart: unless-stopped

  db:
    image: postgres:14-alpine
    environment:
      POSTGRES_DB: velya
      POSTGRES_USER: velya
      POSTGRES_PASSWORD: changeme  # ⚠️ Changez-moi !
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - velya-api
    restart: unless-stopped

volumes:
  postgres_data:
```

#### 2. Générer une Clé Secrète

```bash
export SECRET_KEY=$(openssl rand -hex 32)
echo "SECRET_KEY=$SECRET_KEY" > .env
```

#### 3. Télécharger la Config Nginx

```bash
curl -o nginx.conf https://raw.githubusercontent.com/lowrisk75/velya-server/main/deployment/nginx-velya.conf
```

#### 4. Démarrer les Services

```bash
docker-compose up -d
```

#### 5. Créer Votre Compte

```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"votre@email.com","password":"votre_password"}'
```

**🎉 Installation terminée !** Accédez au dashboard sur `http://localhost`

---

## Configuration de l'App iOS

1. Ouvrez **Velya** sur votre iPhone
2. Allez dans **Réglages** ⚙️
3. Activez **"Remote Server"**
4. Entrez l'URL : `http://votre-serveur.local` ou `https://velya.yourdomain.com`
5. Connectez-vous avec vos identifiants
6. ✅ Vos alarmes se synchronisent automatiquement !

---

## Cas d'Usage Réels

### 1. Intégration Home Assistant : Vacation Mode

**Problème :** Quand vous partez en vacances, vous ne voulez pas que vos alarmes matinales sonnent.

**Solution :** Automatisation Home Assistant qui désactive toutes vos alarmes Velya.

```yaml
# configuration.yaml
rest_command:
  velya_disable_all:
    url: "https://velya.yourdomain.com/webhook/trigger/YOUR_WEBHOOK_ID"
    method: POST
    headers:
      Content-Type: application/json
      X-Verification-Code: "YOUR_CODE"
    payload: |
      {"action": "disable"}

automation:
  - alias: "Vacation Mode - Disable Alarms"
    trigger:
      - platform: state
        entity_id: input_boolean.vacation_mode
        to: "on"
    action:
      - service: rest_command.velya_disable_all
      - service: notify.mobile_app
        data:
          message: "✅ Toutes vos alarmes Velya ont été désactivées"
```

### 2. Réveil Dynamique selon la Météo

**Problème :** Lever 30 min plus tôt quand il neige (déneiger la voiture).

**Solution :** Node-RED qui ajuste l'heure de votre réveil.

```javascript
// Node-RED function node
const weather = msg.payload.weather; // OpenWeatherMap
const snowThreshold = 5; // cm

if (weather.snow > snowThreshold) {
    // Avancer de 30 min
    msg.payload = {
        action: "adjustTime",
        offsetMinutes: -30
    };
    return msg;
}
```

### 3. Réunion Matinale Exceptionnelle

**Problème :** Calendrier Google annonce une réunion 8h demain (normalement vous vous levez à 9h).

**Solution :** Zapier qui avance votre réveil automatiquement.

```
Trigger: Google Calendar - Event Starts Tomorrow at 8:00 AM
Filter: Event title contains "meeting" OR "réunion"
Action: Webhook POST to Velya
  URL: https://velya.yourdomain.com/webhook/trigger/WEBHOOK_ID
  Headers: X-Verification-Code: YOUR_CODE
  Body: {"action": "setTime", "hour": 6, "minute": 30}
```

### 4. Dashboard Famille Partagé

**Scénario :** Vous et votre conjoint(e) partagez le serveur.

- **Chacun son compte** (isolation totale)
- **Dashboard web accessible** depuis n'importe quel navigateur
- **Timeline commune** visible sur une tablette murale
- **Webhooks partagés** (ex: "désactiver tous les réveils famille")

---

## Architecture Technique

### Stack

**Backend (FastAPI + PostgreSQL + Redis)**
- Python 3.11 async/await
- SQLAlchemy 2.0 (ORM async)
- JWT authentication (30-day tokens)
- Redis rate limiting & pub/sub
- WebSocket real-time sync

**Frontend (Svelte 5 + TailwindCSS)**
- Svelte 5 Runes (reactive)
- Chart.js pour timeline
- Design système Apple (SF Pro)
- Vite build tool

**Infrastructure**
- Docker Compose (one-file deploy)
- Nginx reverse proxy
- PostgreSQL 14 (persistent data)
- Redis 7 (cache + rate limit)

### Sécurité

**Authentication & Authorization**
- JWT avec refresh tokens
- Bcrypt password hashing
- Rate limiting : 10 webhooks/min
- CORS configuré par domaine

**Privacy & Data Isolation**
- Multi-tenant : `user_id` foreign key partout
- Soft deletes pour sync integrity
- Webhooks verification codes (32 bytes cryptographically secure)
- Audit logging complet (WebhookLog table)

**Network Security**
- HTTPS via Let's Encrypt (nginx)
- Cloudflare Tunnel support (zéro port ouvert)
- PostgreSQL & Redis : localhost only (pas d'exposition publique)

### Sync Protocol

**Conflict Resolution : Last-Write-Wins**

1. iOS app envoie changes avec `timestamp`
2. Server compare avec `last_modified_at` en DB
3. Si `client_timestamp < server_timestamp` → **conflict**, server gagne
4. Sinon → appliquer le change
5. Log dans `SyncEvent` table (event sourcing)

**WebSocket Real-Time (Optionnel)**

```javascript
// Client side
const ws = new WebSocket('wss://velya.yourdomain.com/api/sync/ws?token=JWT');

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    // { type: 'sync_event', data: { alarm_id, action } }
    updateLocalAlarms(data);
};
```

---

## Déploiement Avancé

### Cloudflare Tunnel (Accès depuis Internet sans Port Forwarding)

```bash
# Installer cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Authentifier
cloudflared tunnel login

# Créer le tunnel
cloudflared tunnel create velya-server

# Configurer
cat > ~/.cloudflared/config.yml <<EOF
tunnel: velya-server
credentials-file: /root/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: velya.yourdomain.com
    service: http://localhost:80
  - service: http_status:404
EOF

# Installer comme service
sudo cloudflared service install
sudo systemctl start cloudflared

# Router DNS
cloudflared tunnel route dns velya-server velya.yourdomain.com
```

**Avantages :**
- ✅ Zero port forwarding (aucun port ouvert sur votre routeur)
- ✅ HTTPS automatique (certificat Cloudflare)
- ✅ DDoS protection incluse
- ✅ Gratuit (plan Cloudflare Free)

### Tailscale VPN (Accès Privé Famille)

```bash
# Installer Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connecter le serveur
sudo tailscale up

# Partager avec votre famille
# → Tailscale admin panel → Share node
```

**Accès :**
- URL : `http://100.x.y.z` (IP Tailscale du serveur)
- Seulement accessible aux membres de votre Tailnet
- Chiffrement end-to-end automatique

### Backup Automatique

```bash
# Crontab : backup quotidien à 3h du matin
0 3 * * * docker exec velya-db pg_dump -U velya velya | gzip > /backups/velya_$(date +\%Y\%m\%d).sql.gz

# Rétention : garder 30 derniers jours
0 4 * * * find /backups -name "velya_*.sql.gz" -mtime +30 -delete
```

### Monitoring avec Uptime Kuma

```yaml
# Ajouter au docker-compose.yml
  uptime-kuma:
    image: louislam/uptime-kuma:1
    ports:
      - "3001:3001"
    volumes:
      - uptime-kuma:/app/data
    restart: unless-stopped
```

Monitorer :
- API health : `http://localhost:8000/health`
- Frontend : `http://localhost/`
- Database : connexion PostgreSQL
- Redis : PING

---

## Performance & Scalabilité

### Ressources Minimales

- **RAM :** 512 MB (recommandé: 1 GB)
- **CPU :** 1 core (Raspberry Pi 4 suffit)
- **Disk :** 2 GB (5 GB recommandé)

### Optimisations PostgreSQL

```sql
-- Indexes pour queries fréquentes
CREATE INDEX idx_alarms_user_id ON alarms(user_id);
CREATE INDEX idx_alarms_client_id ON alarms(client_id);
CREATE INDEX idx_alarms_enabled ON alarms(is_enabled) WHERE deleted_at IS NULL;
CREATE INDEX idx_sync_events_timestamp ON sync_events(timestamp DESC);
CREATE INDEX idx_webhook_logs_triggered_at ON webhook_logs(triggered_at DESC);
```

### Nginx Caching

```nginx
# Cacher les endpoints stats (5 min TTL)
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m inactive=60m;

location /api/stats {
    proxy_cache api_cache;
    proxy_cache_valid 200 5m;
    proxy_pass http://velya-api:8000;
}
```

### Uvicorn Workers

```bash
# 4 workers pour serveur multi-core
uvicorn backend.main:app --workers 4 --host 0.0.0.0 --port 8000
```

---

## FAQ

### L'app iOS peut-elle fonctionner sans serveur ?

**Oui, absolument !** Velya est conçue pour fonctionner 100% localement par défaut. Toutes vos alarmes sont stockées dans SwiftData sur votre iPhone. Le serveur self-hosted est une fonctionnalité **optionnelle** pour les power users qui veulent :
- Gérer leurs alarmes depuis un navigateur web
- Intégrer avec Home Assistant / Node-RED
- Synchroniser entre plusieurs appareils

### Mes données sont-elles vraiment privées ?

**Oui.** Contrairement aux services cloud classiques :
- Vous hébergez le serveur **chez vous** (Raspberry Pi, NAS, etc.)
- Vos données ne transitent **jamais** par les serveurs de LorisLabs
- Vous avez le **contrôle total** (backup, export, suppression)
- **Aucun tracking**, aucune analyse comportementale
- **Open source** : le code est auditable sur GitHub

### Puis-je utiliser un NAS Synology/QNAP ?

**Oui !** La plupart des NAS modernes supportent Docker :

**Synology :**
- Installer **Docker** depuis Package Center
- Créer un projet Stack avec `docker-compose.yml`
- Démarrer via DSM web interface

**QNAP :**
- Installer **Container Station**
- Import `docker-compose.yml`
- One-click deploy

### Combien ça coûte ?

**Serveur self-hosted : 0€**
- Code open source (MIT License)
- Pas d'abonnement
- Aucun frais récurrent

**Infrastructure (exemples) :**
- Raspberry Pi 4 (2GB) : ~50€ one-time
- NAS déjà possédé : 0€
- VPS Hetzner CX11 : 3.79€/mois
- VPS DigitalOcean Droplet : 6$/mois

### Le serveur fonctionne-t-il hors-ligne ?

**Oui, si hébergé localement.** Tant que :
- Le serveur est sur votre réseau local (Raspberry Pi, NAS)
- Votre iPhone est sur le même Wi-Fi
- Pas besoin d'Internet

Pour l'accès depuis l'extérieur :
- Cloudflare Tunnel (gratuit)
- Tailscale VPN (gratuit jusqu'à 100 devices)
- VPN classique (WireGuard, OpenVPN)

### Puis-je partager avec ma famille ?

**Oui !** Le serveur supporte plusieurs utilisateurs :
- Chacun a son propre compte (isolation totale)
- Chacun voit **seulement** ses alarmes
- Possibilité de webhooks partagés (ex: "désactiver tous les réveils famille")

Créez simplement un compte par personne :
```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"membre@famille.com","password":"password"}'
```

### Comment mettre à jour ?

**Docker Compose (recommandé) :**
```bash
docker-compose pull
docker-compose up -d
```

**L'image Docker est automatiquement buildée** à chaque release GitHub et publiée sur `ghcr.io/lowrisk75/velya-server:latest`.

### Besoin d'aide ?

- 📖 **Documentation complète :** [GitHub Wiki](https://github.com/lowrisk75/velya-server/wiki)
- 💬 **Community :** [GitHub Discussions](https://github.com/lowrisk75/velya-server/discussions)
- 📧 **Support :** [support@lorislab.fr](mailto:support@lorislab.fr)
- 🐛 **Bug Report :** [GitHub Issues](https://github.com/lowrisk75/velya-server/issues)

---

## Roadmap

### Version 1.1 (Q3 2026)
- [ ] Apple Shortcuts integration
- [ ] Siri voice commands ("Hey Siri, disable my morning alarm")
- [ ] Push notifications (alarm created from dashboard → notif iOS)
- [ ] Calendar sync (Google Calendar, Apple Calendar)

### Version 1.2 (Q4 2026)
- [ ] Alembic migrations (database schema versioning)
- [ ] Admin panel (user management, system stats)
- [ ] Multi-language support (EN, FR, ES, DE)
- [ ] Android app (React Native)

### Version 2.0 (2027)
- [ ] Sleep tracking integration (Apple Health, Oura)
- [ ] Smart wake window (réveil optimal dans une fenêtre de 30 min)
- [ ] Alarm templates & sharing
- [ ] Community marketplace (partage de règles intelligentes)

---

## Contribuer

Velya Server est **open source** (MIT License). Les contributions sont les bienvenues !

### Setup Dev

```bash
# Clone
git clone https://github.com/lowrisk75/velya-server.git
cd velya-server

# Backend
python3 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.main:app --reload

# Frontend
cd frontend
npm install
npm run dev
```

### Stack & Tools

- **Backend :** FastAPI, SQLAlchemy 2.0, asyncpg, Redis
- **Frontend :** Svelte 5, Vite, TailwindCSS, Chart.js
- **Testing :** pytest, playwright
- **CI/CD :** GitHub Actions
- **Docker :** Multi-stage builds, Alpine base

### Contribuer

1. Fork le repo
2. Créer une branche (`git checkout -b feature/awesome`)
3. Commit (`git commit -m 'feat: add awesome feature'`)
4. Push (`git push origin feature/awesome`)
5. Ouvrir une Pull Request

---

## Conclusion : Reprenez le Contrôle

Dans un monde où nos données sont constamment monétisées, **Velya adopte une approche radicalement différente** :

✅ **Privacy-First** : Vos alarmes restent chez vous  
✅ **Self-Hosted** : Vous contrôlez l'infrastructure  
✅ **Open Source** : Code auditable, transparent  
✅ **Zero Lock-In** : Export de toutes vos données en un clic  
✅ **Gratuit** : Aucun abonnement, aucun coût caché

Que vous soyez un **homelab enthusiast** avec un Proxmox, un **power user** avec un Raspberry Pi, ou un **développeur** avec un VPS, Velya Server vous donne les outils pour gérer vos réveils **à votre façon**.

---

**Ready to take control?**

🚀 [Install Velya Server](https://github.com/lowrisk75/velya-server)  
📱 [Download Velya on App Store](https://apps.apple.com/app/velya/idXXXXXXXX)  
💬 [Join the Community](https://github.com/lowrisk75/velya-server/discussions)

---

*Écrit avec ❤️ par [LorisLabs](https://lorislab.fr)*  
*Open Source • Privacy-First • Made in France 🇫🇷*
