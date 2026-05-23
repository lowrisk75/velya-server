<script>
  import { onMount } from 'svelte';
  import { webhooks } from '../lib/api.js';

  let webhooksList = [];
  let isLoading = true;
  let error = '';
  let showCreateModal = false;
  let showUrlModal = false;
  let selectedWebhook = null;

  // Form state
  let newName = '';
  let newAlarmId = '';
  let createdWebhook = null;

  async function loadWebhooks() {
    isLoading = true;
    error = '';

    try {
      webhooksList = await webhooks.list();
    } catch (err) {
      error = 'Erreur lors du chargement des webhooks';
      console.error(err);
    } finally {
      isLoading = false;
    }
  }

  async function createWebhook() {
    try {
      createdWebhook = await webhooks.create({
        name: newName,
        alarm_id: newAlarmId ? parseInt(newAlarmId) : null
      });

      showCreateModal = false;
      showUrlModal = true;
      newName = '';
      newAlarmId = '';

      await loadWebhooks();
    } catch (err) {
      console.error('Failed to create webhook:', err);
      alert('Erreur lors de la création du webhook');
    }
  }

  async function deleteWebhook(id) {
    if (!confirm('Supprimer ce webhook ?')) return;

    try {
      await webhooks.delete(id);
      await loadWebhooks();
    } catch (err) {
      console.error('Failed to delete webhook:', err);
    }
  }

  function copyToClipboard(text) {
    navigator.clipboard.writeText(text);
    alert('Copié dans le presse-papier !');
  }

  function showDetails(webhook) {
    selectedWebhook = webhook;
    showUrlModal = true;
  }

  onMount(() => {
    loadWebhooks();
  });

  function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('fr-FR', {
      day: 'numeric',
      month: 'short',
      year: 'numeric'
    });
  }
</script>

<div class="p-8">
  <div class="max-w-7xl mx-auto">
    <div class="flex items-center justify-between mb-8">
      <div>
        <h1 class="text-3xl font-display font-bold">Webhooks</h1>
        <p class="text-text-secondary mt-1">Contrôlez vos réveils depuis Home Assistant ou Node-RED</p>
      </div>

      <button
        onclick={() => showCreateModal = true}
        class="btn btn-primary"
      >
        <span class="flex items-center gap-2">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Nouveau webhook
        </span>
      </button>
    </div>

    {#if isLoading}
      <div class="card text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-4 border-gray-200 border-t-primary"></div>
        <p class="text-text-secondary mt-4">Chargement...</p>
      </div>
    {:else if error}
      <div class="card bg-red-50 border-red-200 text-red-700">
        {error}
      </div>
    {:else}
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        {#each webhooksList as webhook}
          <div class="card hover:shadow-md transition-shadow">
            <div class="flex items-start justify-between mb-4">
              <div>
                <h3 class="font-semibold text-lg">{webhook.name}</h3>
                <p class="text-sm text-text-secondary mt-1">Créé le {formatDate(webhook.created_at)}</p>
              </div>

              <span class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs {webhook.is_enabled ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'}">
                {webhook.is_enabled ? 'Actif' : 'Inactif'}
              </span>
            </div>

            <div class="space-y-2 text-sm">
              <div class="flex items-center justify-between">
                <span class="text-text-secondary">Déclenchements:</span>
                <span class="font-medium">{webhook.total_triggers}</span>
              </div>

              <div class="flex items-center justify-between">
                <span class="text-text-secondary">Limite:</span>
                <span class="font-medium">{webhook.rate_limit}/min</span>
              </div>

              {#if webhook.last_trigger_at}
                <div class="flex items-center justify-between">
                  <span class="text-text-secondary">Dernier:</span>
                  <span class="font-medium">{formatDate(webhook.last_trigger_at)}</span>
                </div>
              {/if}
            </div>

            <div class="flex items-center gap-2 mt-4 pt-4 border-t border-gray-100">
              <button
                onclick={() => showDetails(webhook)}
                class="flex-1 btn btn-secondary text-sm"
              >
                Voir URL
              </button>

              <button
                onclick={() => deleteWebhook(webhook.id)}
                class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                title="Supprimer"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </div>
        {/each}

        {#if webhooksList.length === 0}
          <div class="col-span-2 card text-center py-12">
            <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
            </svg>
            <p class="text-text-secondary">Aucun webhook configuré</p>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>

<!-- Create Modal -->
{#if showCreateModal}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4" onclick={() => showCreateModal = false}>
    <div class="card max-w-md w-full" on:click|stopPropagation>
      <h2 class="text-2xl font-display font-semibold mb-6">Nouveau webhook</h2>

      <form on:submit|preventDefault={createWebhook} class="space-y-4">
        <div>
          <label for="name" class="block text-sm font-medium mb-2">Nom</label>
          <input
            type="text"
            id="name"
            bind:value={newName}
            class="input"
            placeholder="Réveil du matin"
            required
          />
        </div>

        <div>
          <label for="alarm_id" class="block text-sm font-medium mb-2">Alarm ID (optionnel)</label>
          <input
            type="number"
            id="alarm_id"
            bind:value={newAlarmId}
            class="input"
            placeholder="Laissez vide pour tous les réveils"
          />
          <p class="text-xs text-text-secondary mt-1">Si vide, le webhook affectera tous vos réveils</p>
        </div>

        <div class="flex gap-2">
          <button type="button" onclick={() => showCreateModal = false} class="flex-1 btn btn-secondary">
            Annuler
          </button>
          <button type="submit" class="flex-1 btn btn-primary">
            Créer
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}

<!-- URL Details Modal -->
{#if showUrlModal && (createdWebhook || selectedWebhook)}
  {@const webhook = createdWebhook || selectedWebhook}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4" onclick={() => { showUrlModal = false; createdWebhook = null; selectedWebhook = null; }}>
    <div class="card max-w-2xl w-full" on:click|stopPropagation>
      <h2 class="text-2xl font-display font-semibold mb-6">{webhook.name}</h2>

      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium mb-2">Webhook URL</label>
          <div class="flex gap-2">
            <input
              type="text"
              value="https://velya.kevinn.ie/webhook/trigger/{webhook.webhook_id}"
              readonly
              class="input flex-1 font-mono text-sm"
            />
            <button
              onclick={() => copyToClipboard(`https://velya.kevinn.ie/webhook/trigger/${webhook.webhook_id}`)}
              class="btn btn-secondary"
            >
              Copier
            </button>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">Verification Code</label>
          <div class="flex gap-2">
            <input
              type="text"
              value={webhook.verification_code}
              readonly
              class="input flex-1 font-mono text-sm"
            />
            <button
              onclick={() => copyToClipboard(webhook.verification_code)}
              class="btn btn-secondary"
            >
              Copier
            </button>
          </div>
        </div>

        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 text-sm">
          <p class="font-medium mb-2">Exemple Home Assistant:</p>
          <pre class="bg-white p-3 rounded overflow-x-auto text-xs"><code>rest_command:
  velya_disable_alarm:
    url: "https://velya.kevinn.ie/webhook/trigger/{webhook.webhook_id}"
    method: POST
    headers:
      Content-Type: application/json
      X-Verification-Code: "{webhook.verification_code}"
    payload: |
      {"{"}"action": "disable"{"}"}</code></pre>
        </div>
      </div>

      <button onclick={() => { showUrlModal = false; createdWebhook = null; selectedWebhook = null; }} class="btn btn-primary w-full mt-6">
        Fermer
      </button>
    </div>
  </div>
{/if}
