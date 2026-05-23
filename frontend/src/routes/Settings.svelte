<script>
  let serverUrl = 'https://velya.kevinn.ie';

  // Expandable sections state
  let dockerGuide = false;
  let dockerComposeGuide = false;
  let lxcGuide = false;
  let webhookDocs = false;
  let troubleshooting = false;
  let faq = false;

  function copyServerUrl() {
    navigator.clipboard.writeText(serverUrl);
    alert('URL copiée !');
  }

  function copyToClipboard(text) {
    navigator.clipboard.writeText(text);
    alert('Copié !');
  }
</script>

<div class="p-8">
  <div class="max-w-4xl mx-auto">
    <div class="mb-8">
      <h1 class="text-3xl font-display font-bold">Settings</h1>
      <p class="text-text-secondary mt-1">Configuration du serveur Velya</p>
    </div>

    <!-- Quick Start -->
    <div class="card mb-6 bg-gradient-to-br from-primary/5 to-purple-500/5 border-primary/20">
      <div class="flex items-start gap-4">
        <div class="flex-shrink-0 w-12 h-12 bg-primary rounded-xl flex items-center justify-center">
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
          </svg>
        </div>
        <div class="flex-1">
          <h2 class="text-xl font-display font-semibold mb-2">Self-Hosting Velya Server</h2>
          <p class="text-text-secondary mb-4">
            Velya fonctionne 100% localement sur votre iPhone sans serveur. Cette fonctionnalité optionnelle vous permet d'héberger votre propre serveur pour gérer vos alarmes à distance.
          </p>
          <div class="flex gap-3">
            <a href="#docker-compose" onclick={() => dockerComposeGuide = true} class="btn btn-primary">
              Quick Start (5 min)
            </a>
            <a href="https://github.com/lowrisk75/velya-server" target="_blank" class="btn btn-secondary">
              GitHub →
            </a>
          </div>
        </div>
      </div>
    </div>

    <!-- Current Server Info -->
    <div class="card mb-6">
      <h2 class="text-xl font-display font-semibold mb-4">Informations Serveur</h2>

      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium mb-2">URL du serveur</label>
          <div class="flex gap-2">
            <input
              type="text"
              value={serverUrl}
              readonly
              class="input flex-1 font-mono"
            />
            <button onclick={copyServerUrl} class="btn btn-secondary">
              Copier
            </button>
          </div>
          <p class="text-xs text-text-secondary mt-1">URL à configurer dans l'app iOS</p>
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">Version</label>
          <input
            type="text"
            value="1.0.0"
            readonly
            class="input"
          />
        </div>

        <div class="flex items-center gap-3 p-4 bg-green-50 border border-green-200 rounded-lg">
          <svg class="w-6 h-6 text-green-600" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
          </svg>
          <div class="text-sm">
            <p class="font-medium text-green-900">Serveur opérationnel</p>
            <p class="text-green-700">Tous les services fonctionnent normalement</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Installation Guides -->
    <div class="space-y-4 mb-6">
      <h2 class="text-xl font-display font-semibold">Guides d'Installation</h2>

      <!-- Docker Compose (Recommended) -->
      <div class="card">
        <button
          onclick={() => dockerComposeGuide = !dockerComposeGuide}
          class="w-full flex items-center justify-between"
        >
          <div class="flex items-center gap-3">
            <span class="inline-flex items-center px-2 py-1 bg-green-100 text-green-700 rounded text-xs font-medium">
              RECOMMANDÉ
            </span>
            <span class="font-semibold">Docker Compose (5 minutes)</span>
          </div>
          <svg class="w-5 h-5 transition-transform {dockerComposeGuide ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {#if dockerComposeGuide}
          <div class="mt-6 space-y-4 pt-6 border-t border-gray-100">
            <div class="prose prose-sm max-w-none">
              <h3 class="font-semibold mb-3">Prérequis</h3>
              <ul class="text-sm text-text-secondary space-y-1">
                <li>Docker & Docker Compose installés</li>
                <li>Un serveur Linux (Raspberry Pi, VPS, NAS, etc.)</li>
                <li>Port 80 et 443 ouverts</li>
              </ul>

              <h3 class="font-semibold mb-3 mt-6">Installation one-liner</h3>
              <div class="relative">
                <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto text-sm"><code>curl -fsSL https://raw.githubusercontent.com/lowrisk75/velya-server/main/install.sh | bash</code></pre>
                <button
                  onclick={() => copyToClipboard("curl -fsSL https://raw.githubusercontent.com/lowrisk75/velya-server/main/install.sh | bash")}
                  class="absolute top-2 right-2 p-2 bg-gray-700 hover:bg-gray-600 rounded text-white text-xs"
                >
                  Copier
                </button>
              </div>

              <h3 class="font-semibold mb-3 mt-6">Ou installation manuelle</h3>
              <div class="space-y-3">
                <div>
                  <p class="text-sm font-medium mb-2">1. Créer docker-compose.yml</p>
                  <div class="relative">
                    <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto text-xs"><code>{`version: '3.8'
services:
  velya-api:
    image: ghcr.io/lowrisk75/velya-server:latest
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://velya:changeme@db/velya
      - REDIS_URL=redis://redis:6379
      - SECRET_KEY=\${SECRET_KEY}
    depends_on:
      - db
      - redis

  db:
    image: postgres:14-alpine
    environment:
      POSTGRES_DB: velya
      POSTGRES_USER: velya
      POSTGRES_PASSWORD: changeme
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine

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

volumes:
  postgres_data:`}</code></pre>
                    <button
                      onclick={() => copyToClipboard("version: '3.8'\nservices:\n  velya-api:\n    image: ghcr.io/lowrisk75/velya-server:latest\n    ports:\n      - \"8000:8000\"\n    environment:\n      - DATABASE_URL=postgresql://velya:changeme@db/velya\n      - REDIS_URL=redis://redis:6379\n      - SECRET_KEY=${SECRET_KEY}\n    depends_on:\n      - db\n      - redis\n\n  db:\n    image: postgres:14-alpine\n    environment:\n      POSTGRES_DB: velya\n      POSTGRES_USER: velya\n      POSTGRES_PASSWORD: changeme\n    volumes:\n      - postgres_data:/var/lib/postgresql/data\n\n  redis:\n    image: redis:7-alpine\n\n  nginx:\n    image: nginx:alpine\n    ports:\n      - \"80:80\"\n      - \"443:443\"\n    volumes:\n      - ./nginx.conf:/etc/nginx/nginx.conf\n      - ./ssl:/etc/nginx/ssl\n    depends_on:\n      - velya-api\n\nvolumes:\n  postgres_data:")}
                      class="absolute top-2 right-2 p-2 bg-gray-700 hover:bg-gray-600 rounded text-white text-xs"
                    >
                      Copier
                    </button>
                  </div>
                </div>

                <div>
                  <p class="text-sm font-medium mb-2">2. Générer une clé secrète</p>
                  <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto text-xs"><code>export SECRET_KEY=$(openssl rand -hex 32)</code></pre>
                </div>

                <div>
                  <p class="text-sm font-medium mb-2">3. Démarrer les services</p>
                  <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto text-xs"><code>docker-compose up -d</code></pre>
                </div>

                <div>
                  <p class="text-sm font-medium mb-2">4. Créer votre compte</p>
                  <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto text-xs"><code>{`curl -X POST http://localhost:8000/api/auth/register \\
  -H "Content-Type: application/json" \\
  -d '{"email":"votre@email.com","password":"votre_password"}'`}</code></pre>
                </div>
              </div>

              <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <p class="text-sm font-medium text-blue-900 mb-2">✅ Installation terminée !</p>
                <p class="text-sm text-blue-700">
                  Votre serveur est accessible sur <code class="bg-blue-100 px-2 py-1 rounded">http://localhost</code>
                  <br>Configurez maintenant l'app iOS avec cette URL.
                </p>
              </div>
            </div>
          </div>
        {/if}
      </div>

      <!-- Docker -->
      <div class="card">
        <button
          onclick={() => dockerGuide = !dockerGuide}
          class="w-full flex items-center justify-between"
        >
          <span class="font-semibold">Docker (avancé)</span>
          <svg class="w-5 h-5 transition-transform {dockerGuide ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {#if dockerGuide}
          <div class="mt-6 pt-6 border-t border-gray-100 space-y-4">
            <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto text-sm"><code>{`# Créer un réseau
docker network create velya-net

# PostgreSQL
docker run -d --name velya-db \\
  --network velya-net \\
  -e POSTGRES_DB=velya \\
  -e POSTGRES_USER=velya \\
  -e POSTGRES_PASSWORD=changeme \\
  -v velya-postgres:/var/lib/postgresql/data \\
  postgres:14-alpine

# Redis
docker run -d --name velya-redis \\
  --network velya-net \\
  redis:7-alpine

# API
docker run -d --name velya-api \\
  --network velya-net \\
  -p 8000:8000 \\
  -e DATABASE_URL=postgresql://velya:changeme@velya-db/velya \\
  -e REDIS_URL=redis://velya-redis:6379 \\
  -e SECRET_KEY=$(openssl rand -hex 32) \\
  ghcr.io/lowrisk75/velya-server:latest`}</code></pre>
          </div>
        {/if}
      </div>

      <!-- LXC -->
      <div class="card">
        <button
          onclick={() => lxcGuide = !lxcGuide}
          class="w-full flex items-center justify-between"
        >
          <span class="font-semibold">LXC Container (Proxmox)</span>
          <svg class="w-5 h-5 transition-transform {lxcGuide ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {#if lxcGuide}
          <div class="mt-6 pt-6 border-t border-gray-100 space-y-4">
            <p class="text-sm text-text-secondary">
              Pour Proxmox VE, voir le guide complet:
              <a href="https://github.com/lowrisk75/velya-server/blob/main/DEPLOYMENT.md" target="_blank" class="text-primary hover:underline">
                DEPLOYMENT.md
              </a>
            </p>
            <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto text-sm"><code>{`# Sur Proxmox host
pct create 300 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \\
  --hostname velya-server \\
  --memory 2048 \\
  --cores 2 \\
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \\
  --storage local-lvm \\
  --rootfs local-lvm:8

pct start 300
pct enter 300

# Dans le container
git clone https://github.com/lowrisk75/velya-server.git /tmp/velya
cd /tmp/velya
chmod +x deployment/deploy.sh
./deployment/deploy.sh`}</code></pre>
          </div>
        {/if}
      </div>
    </div>

    <!-- Webhook Documentation -->
    <div class="card mb-6">
      <h2 class="text-xl font-display font-semibold mb-4">Documentation API</h2>

      <div class="space-y-4">
        <div>
          <button
            onclick={() => webhookDocs = !webhookDocs}
            class="w-full flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <span class="font-medium">Endpoints Webhook</span>
            <svg class="w-5 h-5 transition-transform {webhookDocs ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
            </svg>
          </button>

          {#if webhookDocs}
            <div class="mt-4 p-4 bg-gray-50 rounded-lg space-y-4">
              <div>
                <h3 class="font-semibold mb-2">POST /webhook/trigger/{"{webhook_id}"}</h3>
                <p class="text-sm text-text-secondary mb-2">Déclencher une action sur un réveil</p>

                <div class="bg-white p-3 rounded text-sm font-mono overflow-x-auto">
                  <pre><code>{`Headers:
  Content-Type: application/json
  X-Verification-Code: YOUR_CODE

Body (enable):
  {"action": "enable"}

Body (disable):
  {"action": "disable"}

Body (setTime):
  {"action": "setTime", "hour": 7, "minute": 30}

Body (adjustTime):
  {"action": "adjustTime", "offsetMinutes": 15}`}</code></pre>
                </div>
              </div>

              <div>
                <h3 class="font-semibold mb-2">Exemple Home Assistant</h3>
                <div class="bg-white p-3 rounded text-sm font-mono overflow-x-auto">
                  <pre><code>{`rest_command:
  velya_disable:
    url: "${serverUrl}/webhook/trigger/YOUR_WEBHOOK_ID"
    method: POST
    headers:
      Content-Type: application/json
      X-Verification-Code: "YOUR_CODE"
    payload: |
      {"action": "disable"}`}</code></pre>
                </div>
              </div>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Troubleshooting -->
    <div class="card mb-6">
      <button
        onclick={() => troubleshooting = !troubleshooting}
        class="w-full flex items-center justify-between"
      >
        <h2 class="text-xl font-display font-semibold">Dépannage</h2>
        <svg class="w-5 h-5 transition-transform {troubleshooting ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {#if troubleshooting}
        <div class="mt-6 pt-6 border-t border-gray-100 space-y-6">
          <div>
            <h3 class="font-semibold mb-2">❌ L'API ne démarre pas</h3>
            <pre class="bg-gray-900 text-gray-100 p-3 rounded text-sm overflow-x-auto"><code>{`# Vérifier les logs
docker-compose logs velya-api

# Problèmes courants:
# - Erreur DB → vérifier DATABASE_URL
# - Port 8000 occupé → lsof -i :8000
# - Secret manquant → générer SECRET_KEY`}</code></pre>
          </div>

          <div>
            <h3 class="font-semibold mb-2">❌ Le frontend ne charge pas</h3>
            <pre class="bg-gray-900 text-gray-100 p-3 rounded text-sm overflow-x-auto"><code>{`# Reconstruire le frontend
cd frontend
npm run build

# Vérifier nginx
docker-compose logs nginx
nginx -t`}</code></pre>
          </div>

          <div>
            <h3 class="font-semibold mb-2">❌ WebSocket échoue</h3>
            <pre class="bg-gray-900 text-gray-100 p-3 rounded text-sm overflow-x-auto"><code>{`# Tester la connexion WS
wscat -c ws://localhost:8000/api/sync/ws?token=YOUR_JWT

# Vérifier nginx WebSocket config
grep -A 10 "location /api/sync/ws" nginx.conf`}</code></pre>
          </div>

          <div>
            <h3 class="font-semibold mb-2">✅ Vérifier la santé du serveur</h3>
            <pre class="bg-gray-900 text-gray-100 p-3 rounded text-sm overflow-x-auto"><code>{`# API health
curl http://localhost:8000/health

# DB connection
docker exec velya-db psql -U velya -d velya -c "SELECT 1;"

# Redis
docker exec velya-redis redis-cli ping`}</code></pre>
          </div>
        </div>
      {/if}
    </div>

    <!-- FAQ -->
    <div class="card">
      <button
        onclick={() => faq = !faq}
        class="w-full flex items-center justify-between"
      >
        <h2 class="text-xl font-display font-semibold">FAQ</h2>
        <svg class="w-5 h-5 transition-transform {faq ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {#if faq}
        <div class="mt-6 pt-6 border-t border-gray-100 space-y-6">
          <div>
            <h3 class="font-semibold mb-2">Ai-je besoin d'un serveur pour utiliser Velya ?</h3>
            <p class="text-sm text-text-secondary">
              Non ! Velya fonctionne 100% localement sur votre iPhone par défaut. Le serveur est une fonctionnalité optionnelle pour les utilisateurs avancés qui souhaitent gérer leurs alarmes à distance depuis un navigateur web ou via des automations Home Assistant.
            </p>
          </div>

          <div>
            <h3 class="font-semibold mb-2">Mes données sont-elles en sécurité ?</h3>
            <p class="text-sm text-text-secondary">
              Oui ! Puisque vous hébergez votre propre serveur, vos données restent chez vous. Elles ne transitent jamais par les serveurs de LorisLabs. Vous avez le contrôle total sur vos données et votre vie privée.
            </p>
          </div>

          <div>
            <h3 class="font-semibold mb-2">Quel matériel est recommandé ?</h3>
            <p class="text-sm text-text-secondary">
              Un Raspberry Pi 4 (2GB RAM minimum), un NAS Synology/QNAP avec Docker, ou un VPS cloud (DigitalOcean, Hetzner) suffisent amplement. Le serveur consomme très peu de ressources (~200MB RAM).
            </p>
          </div>

          <div>
            <h3 class="font-semibold mb-2">Puis-je accéder au serveur depuis l'extérieur ?</h3>
            <p class="text-sm text-text-secondary">
              Oui, via Cloudflare Tunnel (gratuit) ou un VPN Tailscale. Évitez d'exposer directement le port 80/443 sur Internet sans reverse proxy et HTTPS.
            </p>
          </div>

          <div>
            <h3 class="font-semibold mb-2">Le serveur fonctionne-t-il avec plusieurs utilisateurs ?</h3>
            <p class="text-sm text-text-secondary">
              Oui ! Chaque utilisateur a son propre compte isolé. Idéal pour partager avec votre famille ou quelques amis proches.
            </p>
          </div>

          <div>
            <h3 class="font-semibold mb-2">Comment mettre à jour le serveur ?</h3>
            <p class="text-sm text-text-secondary">
              Docker Compose : <code class="bg-gray-100 px-2 py-1 rounded text-xs">docker-compose pull && docker-compose up -d</code>
              <br>L'image est mise à jour automatiquement sur GitHub Container Registry.
            </p>
          </div>

          <div>
            <h3 class="font-semibold mb-2">Besoin d'aide ?</h3>
            <p class="text-sm text-text-secondary">
              • Documentation complète : <a href="https://github.com/lowrisk75/velya-server" target="_blank" class="text-primary hover:underline">GitHub</a>
              <br>• Support : <a href="mailto:support@lorislab.fr" class="text-primary hover:underline">support@lorislab.fr</a>
              <br>• Community : <a href="https://github.com/lowrisk75/velya-server/discussions" target="_blank" class="text-primary hover:underline">GitHub Discussions</a>
            </p>
          </div>
        </div>
      {/if}
    </div>
  </div>
</div>
