<script>
  import { onMount } from 'svelte';
  import { alarms } from '../lib/api.js';

  let alarmsList = [];
  let isLoading = true;
  let error = '';
  let showCreateModal = false;

  async function loadAlarms() {
    isLoading = true;
    error = '';

    try {
      alarmsList = await alarms.list();
    } catch (err) {
      error = 'Erreur lors du chargement des réveils';
      console.error(err);
    } finally {
      isLoading = false;
    }
  }

  async function toggleAlarm(alarm) {
    try {
      await alarms.update(alarm.id, {
        is_enabled: !alarm.is_enabled
      });
      await loadAlarms();
    } catch (err) {
      console.error('Failed to toggle alarm:', err);
    }
  }

  async function deleteAlarm(id) {
    if (!confirm('Supprimer ce réveil ?')) return;

    try {
      await alarms.delete(id);
      await loadAlarms();
    } catch (err) {
      console.error('Failed to delete alarm:', err);
    }
  }

  onMount(() => {
    loadAlarms();
  });

  function formatTime(timeStr) {
    return timeStr.slice(0, 5);
  }

  function formatRepeatDays(repeatDays) {
    if (!repeatDays || repeatDays.length === 0) return 'Une seule fois';

    const dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return repeatDays.map(d => dayNames[d]).join(', ');
  }
</script>

<div class="p-8">
  <div class="max-w-7xl mx-auto">
    <div class="flex items-center justify-between mb-8">
      <div>
        <h1 class="text-3xl font-display font-bold">Réveils</h1>
        <p class="text-text-secondary mt-1">Gérez vos alarmes à distance</p>
      </div>

      <button
        onclick={() => showCreateModal = true}
        class="btn btn-primary"
      >
        <span class="flex items-center gap-2">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Nouveau réveil
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
      <div class="space-y-4">
        {#each alarmsList as alarm}
          <div class="card hover:shadow-md transition-shadow">
            <div class="flex items-center gap-6">
              <!-- Time -->
              <div class="flex-shrink-0">
                <div class="text-4xl font-display font-bold">{formatTime(alarm.time)}</div>
              </div>

              <!-- Details -->
              <div class="flex-1">
                <h3 class="font-semibold text-lg">{alarm.label || 'Sans nom'}</h3>
                <div class="flex items-center gap-4 mt-1 text-sm text-text-secondary">
                  <span>{formatRepeatDays(alarm.repeat_days)}</span>
                  {#if alarm.sound}
                    <span>• {alarm.sound}</span>
                  {/if}
                  {#if alarm.vibration}
                    <span>• Vibration</span>
                  {/if}
                </div>
              </div>

              <!-- Actions -->
              <div class="flex items-center gap-3">
                <!-- Toggle -->
                <button
                  onclick={() => toggleAlarm(alarm)}
                  class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors {alarm.is_enabled ? 'bg-primary' : 'bg-gray-300'}"
                >
                  <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform {alarm.is_enabled ? 'translate-x-6' : 'translate-x-1'}"></span>
                </button>

                <!-- Delete -->
                <button
                  onclick={() => deleteAlarm(alarm.id)}
                  class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                  title="Supprimer"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        {/each}

        {#if alarmsList.length === 0}
          <div class="card text-center py-12">
            <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p class="text-text-secondary">Aucun réveil configuré</p>
            <p class="text-text-secondary text-sm mt-2">Créez votre premier réveil depuis l'app iOS</p>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>

<!-- Create Modal (placeholder for now) -->
{#if showCreateModal}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4" onclick={() => showCreateModal = false}>
    <div class="card max-w-md w-full" on:click|stopPropagation>
      <h2 class="text-2xl font-display font-semibold mb-4">Nouveau réveil</h2>
      <p class="text-text-secondary mb-6">La création de réveils via le dashboard web sera bientôt disponible. Utilisez l'app iOS pour créer des réveils.</p>
      <button onclick={() => showCreateModal = false} class="btn btn-primary w-full">OK</button>
    </div>
  </div>
{/if}
