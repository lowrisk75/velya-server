<script>
  let serverUrl = $state('https://velya.kevinn.ie');
  let webhookDocs = $state(false);

  function copyServerUrl() {
    navigator.clipboard.writeText(serverUrl);
    alert('URL copiée !');
  }
</script>

<div class="p-8">
  <div class="max-w-4xl mx-auto">
    <div class="mb-8">
      <h1 class="text-3xl font-display font-bold">Settings</h1>
      <p class="text-text-secondary mt-1">Configuration du serveur Velya</p>
    </div>

    <!-- Server Info -->
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
      </div>
    </div>

    <!-- API Documentation -->
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
                  <pre><code>Headers:
  Content-Type: application/json
  X-Verification-Code: YOUR_CODE

Body (enable):
  {"{"}"action": "enable"{"}"}

Body (disable):
  {"{"}"action": "disable"{"}"}

Body (setTime):
  {"{"}"action": "setTime", "hour": 7, "minute": 30{"}"}

Body (adjustTime):
  {"{"}"action": "adjustTime", "offsetMinutes": 15{"}"}</code></pre>
                </div>
              </div>

              <div>
                <h3 class="font-semibold mb-2">Exemple Home Assistant</h3>
                <div class="bg-white p-3 rounded text-sm font-mono overflow-x-auto">
                  <pre><code>rest_command:
  velya_disable:
    url: "{serverUrl}/webhook/trigger/YOUR_WEBHOOK_ID"
    method: POST
    headers:
      Content-Type: application/json
      X-Verification-Code: "YOUR_CODE"
    payload: |
      {"{"}"action": "disable"{"}"}</code></pre>
                </div>
              </div>
            </div>
          {/if}
        </div>

        <div class="flex items-center gap-3 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <svg class="w-6 h-6 text-blue-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div class="text-sm">
            <p class="font-medium mb-1">Documentation complète</p>
            <p class="text-text-secondary">Voir le fichier README.md pour la documentation complète et les exemples d'intégration</p>
          </div>
        </div>
      </div>
    </div>

    <!-- App Configuration -->
    <div class="card">
      <h2 class="text-xl font-display font-semibold mb-4">Configuration App iOS</h2>

      <div class="space-y-4 text-sm">
        <div class="flex items-start gap-3">
          <div class="flex-shrink-0 w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-xs font-bold">
            1
          </div>
          <div>
            <p class="font-medium mb-1">Ouvrir l'app Velya</p>
            <p class="text-text-secondary">Sur votre iPhone, ouvrez l'application Velya</p>
          </div>
        </div>

        <div class="flex items-start gap-3">
          <div class="flex-shrink-0 w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-xs font-bold">
            2
          </div>
          <div>
            <p class="font-medium mb-1">Aller dans Réglages</p>
            <p class="text-text-secondary">Appuyez sur l'icône ⚙️ en haut à droite</p>
          </div>
        </div>

        <div class="flex items-start gap-3">
          <div class="flex-shrink-0 w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-xs font-bold">
            3
          </div>
          <div>
            <p class="font-medium mb-1">Configurer le serveur distant</p>
            <p class="text-text-secondary">Entrez l'URL: <code class="bg-gray-100 px-2 py-1 rounded">{serverUrl}</code></p>
          </div>
        </div>

        <div class="flex items-start gap-3">
          <div class="flex-shrink-0 w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-xs font-bold">
            4
          </div>
          <div>
            <p class="font-medium mb-1">Connexion</p>
            <p class="text-text-secondary">Connectez-vous avec votre email et mot de passe</p>
          </div>
        </div>

        <div class="flex items-start gap-3">
          <div class="flex-shrink-0 w-6 h-6 bg-green-600 text-white rounded-full flex items-center justify-center text-xs font-bold">
            ✓
          </div>
          <div>
            <p class="font-medium mb-1">Synchronisation active</p>
            <p class="text-text-secondary">Vos réveils sont maintenant synchronisés avec le serveur</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
