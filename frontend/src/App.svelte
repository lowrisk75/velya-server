<script>
  import { Router, Route, Link } from 'svelte-routing';
  import { auth } from './lib/api.js';

  import Login from './routes/Login.svelte';
  import Timeline from './routes/Timeline.svelte';
  import Alarms from './routes/Alarms.svelte';
  import Webhooks from './routes/Webhooks.svelte';
  import Analytics from './routes/Analytics.svelte';
  import Settings from './routes/Settings.svelte';

  let isAuthenticated = $state(auth.isAuthenticated());

  function handleLogout() {
    auth.logout();
    isAuthenticated = false;
  }
</script>

<Router>
  {#if !isAuthenticated}
    <Route path="*">
      <Login on:login={() => isAuthenticated = true} />
    </Route>
  {:else}
    <div class="min-h-screen flex">
      <!-- Sidebar -->
      <aside class="w-64 bg-surface border-r border-gray-200 flex flex-col">
        <div class="p-6 border-b border-gray-200">
          <h1 class="text-2xl font-display font-bold text-primary">Velya</h1>
          <p class="text-sm text-text-secondary mt-1">Remote Dashboard</p>
        </div>

        <nav class="flex-1 p-4 space-y-2">
          <Link to="/timeline" class="block px-4 py-2 rounded-lg hover:bg-gray-100 transition-colors">
            <span class="flex items-center gap-3">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              Timeline
            </span>
          </Link>

          <Link to="/alarms" class="block px-4 py-2 rounded-lg hover:bg-gray-100 transition-colors">
            <span class="flex items-center gap-3">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Alarms
            </span>
          </Link>

          <Link to="/webhooks" class="block px-4 py-2 rounded-lg hover:bg-gray-100 transition-colors">
            <span class="flex items-center gap-3">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
              Webhooks
            </span>
          </Link>

          <Link to="/analytics" class="block px-4 py-2 rounded-lg hover:bg-gray-100 transition-colors">
            <span class="flex items-center gap-3">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
              Analytics
            </span>
          </Link>

          <Link to="/settings" class="block px-4 py-2 rounded-lg hover:bg-gray-100 transition-colors">
            <span class="flex items-center gap-3">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              Settings
            </span>
          </Link>
        </nav>

        <div class="p-4 border-t border-gray-200">
          <button onclick={handleLogout} class="w-full px-4 py-2 text-left text-red-600 rounded-lg hover:bg-red-50 transition-colors">
            <span class="flex items-center gap-3">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
              </svg>
              Logout
            </span>
          </button>
        </div>
      </aside>

      <!-- Main content -->
      <main class="flex-1 overflow-auto">
        <Route path="/" component={Timeline} />
        <Route path="/timeline" component={Timeline} />
        <Route path="/alarms" component={Alarms} />
        <Route path="/webhooks" component={Webhooks} />
        <Route path="/analytics" component={Analytics} />
        <Route path="/settings" component={Settings} />
      </main>
    </div>
  {/if}
</Router>
