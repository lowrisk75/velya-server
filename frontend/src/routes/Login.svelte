<script>
  import { createEventDispatcher } from 'svelte';
  import { auth, ApiError } from '../lib/api.js';

  const dispatch = createEventDispatcher();

  let email = $state('');
  let password = $state('');
  let isLoading = $state(false);
  let error = $state('');

  async function handleLogin() {
    error = '';
    isLoading = true;

    try {
      await auth.login(email, password);
      dispatch('login');
    } catch (err) {
      if (err instanceof ApiError) {
        error = 'Email ou mot de passe incorrect';
      } else {
        error = 'Erreur de connexion au serveur';
      }
    } finally {
      isLoading = false;
    }
  }
</script>

<div class="min-h-screen flex items-center justify-center bg-background px-4">
  <div class="max-w-md w-full">
    <div class="text-center mb-8">
      <h1 class="text-4xl font-display font-bold text-primary mb-2">Velya</h1>
      <p class="text-text-secondary">Gestion à distance de vos réveils</p>
    </div>

    <div class="card">
      <h2 class="text-2xl font-display font-semibold mb-6">Connexion</h2>

      {#if error}
        <div class="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      {/if}

      <form on:submit|preventDefault={handleLogin} class="space-y-4">
        <div>
          <label for="email" class="block text-sm font-medium mb-2">Email</label>
          <input
            type="email"
            id="email"
            bind:value={email}
            class="input"
            placeholder="mail@example.com"
            required
            disabled={isLoading}
          />
        </div>

        <div>
          <label for="password" class="block text-sm font-medium mb-2">Mot de passe</label>
          <input
            type="password"
            id="password"
            bind:value={password}
            class="input"
            placeholder="••••••••"
            required
            disabled={isLoading}
          />
        </div>

        <button
          type="submit"
          class="btn btn-primary w-full"
          disabled={isLoading}
        >
          {isLoading ? 'Connexion...' : 'Se connecter'}
        </button>
      </form>
    </div>
  </div>
</div>
