<script>
  import { onMount } from 'svelte';
  import { stats } from '../lib/api.js';

  let alarmStats = $state(null);
  let webhookStats = $state(null);
  let isLoading = $state(true);
  let error = $state('');

  async function loadStats() {
    isLoading = true;
    error = '';

    try {
      [alarmStats, webhookStats] = await Promise.all([
        stats.alarms(),
        stats.webhooks()
      ]);
    } catch (err) {
      error = 'Erreur lors du chargement des statistiques';
      console.error(err);
    } finally {
      isLoading = false;
    }
  }

  onMount(() => {
    loadStats();
  });

  function percentage(value, total) {
    if (total === 0) return 0;
    return Math.round((value / total) * 100);
  }
</script>

<div class="p-8">
  <div class="max-w-7xl mx-auto">
    <div class="mb-8">
      <h1 class="text-3xl font-display font-bold">Analytics</h1>
      <p class="text-text-secondary mt-1">Statistiques d'utilisation de vos réveils</p>
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
    {:else if alarmStats && webhookStats}
      <!-- Alarm Statistics -->
      <div class="mb-8">
        <h2 class="text-xl font-display font-semibold mb-4">Réveils</h2>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <!-- Total Alarms -->
          <div class="card">
            <div class="flex items-center justify-between mb-2">
              <span class="text-text-secondary text-sm">Total</span>
              <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="text-3xl font-display font-bold">{alarmStats.total_alarms}</div>
          </div>

          <!-- Enabled -->
          <div class="card">
            <div class="flex items-center justify-between mb-2">
              <span class="text-text-secondary text-sm">Activés</span>
              <svg class="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="text-3xl font-display font-bold">{alarmStats.enabled_alarms}</div>
            <div class="text-sm text-text-secondary mt-1">
              {percentage(alarmStats.enabled_alarms, alarmStats.total_alarms)}% du total
            </div>
          </div>

          <!-- Disabled -->
          <div class="card">
            <div class="flex items-center justify-between mb-2">
              <span class="text-text-secondary text-sm">Désactivés</span>
              <svg class="w-5 h-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="text-3xl font-display font-bold">{alarmStats.disabled_alarms}</div>
            <div class="text-sm text-text-secondary mt-1">
              {percentage(alarmStats.disabled_alarms, alarmStats.total_alarms)}% du total
            </div>
          </div>

          <!-- Recurring -->
          <div class="card">
            <div class="flex items-center justify-between mb-2">
              <span class="text-text-secondary text-sm">Récurrents</span>
              <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
            </div>
            <div class="text-3xl font-display font-bold">{alarmStats.recurring_alarms}</div>
            <div class="text-sm text-text-secondary mt-1">
              {alarmStats.one_time_alarms} unique{alarmStats.one_time_alarms > 1 ? 's' : ''}
            </div>
          </div>
        </div>

        <!-- Wake Time Stats -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <div class="card">
            <h3 class="font-semibold mb-3">Heure moyenne de réveil</h3>
            <div class="text-5xl font-display font-bold text-primary">{alarmStats.avg_wake_time}</div>
          </div>

          <div class="card">
            <h3 class="font-semibold mb-3">Heure la plus fréquente</h3>
            <div class="text-5xl font-display font-bold text-purple-600">{alarmStats.most_common_time}</div>
          </div>
        </div>
      </div>

      <!-- Webhook Statistics -->
      <div>
        <h2 class="text-xl font-display font-semibold mb-4">Webhooks</h2>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <!-- Total Webhooks -->
          <div class="card">
            <div class="flex items-center justify-between mb-2">
              <span class="text-text-secondary text-sm">Total</span>
              <svg class="w-5 h-5 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <div class="text-3xl font-display font-bold">{webhookStats.total_webhooks}</div>
          </div>

          <!-- Enabled Webhooks -->
          <div class="card">
            <div class="flex items-center justify-between mb-2">
              <span class="text-text-secondary text-sm">Actifs</span>
              <svg class="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="text-3xl font-display font-bold">{webhookStats.enabled_webhooks}</div>
            <div class="text-sm text-text-secondary mt-1">
              {percentage(webhookStats.enabled_webhooks, webhookStats.total_webhooks)}% du total
            </div>
          </div>

          <!-- Triggers (30d) -->
          <div class="card">
            <div class="flex items-center justify-between mb-2">
              <span class="text-text-secondary text-sm">Déclenchements (30j)</span>
              <svg class="w-5 h-5 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
              </svg>
            </div>
            <div class="text-3xl font-display font-bold">{webhookStats.total_triggers_last_30d}</div>
          </div>
        </div>

        <!-- Most Active Webhook -->
        {#if webhookStats.most_active_webhook && webhookStats.most_active_webhook.id}
          <div class="card mt-4">
            <h3 class="font-semibold mb-3">Webhook le plus actif</h3>
            <div class="flex items-center justify-between">
              <div>
                <p class="font-medium text-lg">{webhookStats.most_active_webhook.name}</p>
                <p class="text-sm text-text-secondary">ID: {webhookStats.most_active_webhook.id}</p>
              </div>
              <div class="text-right">
                <p class="text-3xl font-display font-bold text-primary">{webhookStats.most_active_webhook.total_triggers}</p>
                <p class="text-sm text-text-secondary">déclenchements</p>
              </div>
            </div>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>
