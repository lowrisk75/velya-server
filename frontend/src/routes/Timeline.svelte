<script>
  import { onMount } from 'svelte';
  import { stats } from '../lib/api.js';
  import TimelineChart from '../components/TimelineChart.svelte';

  let timelineData = $state(null);
  let isLoading = $state(true);
  let error = $state('');
  let days = $state(7);

  async function loadTimeline() {
    isLoading = true;
    error = '';

    try {
      timelineData = await stats.timeline(days);
    } catch (err) {
      error = 'Erreur lors du chargement du calendrier';
      console.error(err);
    } finally {
      isLoading = false;
    }
  }

  onMount(() => {
    loadTimeline();
  });

  function formatDate(dateStr) {
    const date = new Date(dateStr);
    return new Intl.DateTimeFormat('fr-FR', {
      weekday: 'short',
      day: 'numeric',
      month: 'short'
    }).format(date);
  }

  function formatTime(timeStr) {
    return timeStr.slice(0, 5); // HH:MM
  }

  // Group items by day
  $: itemsByDay = timelineData?.items.reduce((acc, item) => {
    if (!acc[item.day]) {
      acc[item.day] = [];
    }
    acc[item.day].push(item);
    return acc;
  }, {}) || {};

  $: sortedDays = Object.keys(itemsByDay).sort();
</script>

<div class="p-8">
  <div class="max-w-7xl mx-auto">
    <div class="flex items-center justify-between mb-8">
      <div>
        <h1 class="text-3xl font-display font-bold">Timeline</h1>
        <p class="text-text-secondary mt-1">Calendrier de vos réveils programmés</p>
      </div>

      <div class="flex items-center gap-2">
        <label for="days" class="text-sm text-text-secondary">Jours:</label>
        <select
          id="days"
          bind:value={days}
          onchange={loadTimeline}
          class="input w-24"
        >
          <option value={3}>3</option>
          <option value={7}>7</option>
          <option value={14}>14</option>
          <option value={30}>30</option>
        </select>
      </div>
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
    {:else if timelineData}
      <!-- Chart visualization -->
      <div class="card mb-6">
        <TimelineChart items={timelineData.items} />
      </div>

      <!-- Daily breakdown -->
      <div class="space-y-4">
        {#each sortedDays as day}
          <div class="card">
            <h3 class="font-display font-semibold text-lg mb-4">{formatDate(day)}</h3>

            <div class="space-y-2">
              {#each itemsByDay[day] as item}
                <div class="flex items-center gap-4 p-3 rounded-lg hover:bg-gray-50 transition-colors">
                  <div class="flex-shrink-0 w-16 text-center">
                    <span class="text-2xl font-display font-semibold">{formatTime(item.time)}</span>
                  </div>

                  <div class="flex-1">
                    <p class="font-medium">{item.label}</p>
                    {#if item.repeat_days && item.repeat_days.length > 0}
                      <p class="text-sm text-text-secondary">
                        Répète: {item.repeat_days.map(d => ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'][d]).join(', ')}
                      </p>
                    {:else}
                      <p class="text-sm text-text-secondary">Une seule fois</p>
                    {/if}
                  </div>

                  <div class="flex-shrink-0">
                    {#if item.is_enabled}
                      <span class="inline-flex items-center gap-1 px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm">
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                        </svg>
                        Activé
                      </span>
                    {:else}
                      <span class="inline-flex items-center gap-1 px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                        </svg>
                        Désactivé
                      </span>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          </div>
        {/each}
      </div>

      {#if sortedDays.length === 0}
        <div class="card text-center py-12">
          <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p class="text-text-secondary">Aucun réveil programmé</p>
        </div>
      {/if}
    {/if}
  </div>
</div>
