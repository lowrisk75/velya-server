// API client for Velya backend

const API_BASE = import.meta.env.VITE_API_URL || '';

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function request(endpoint, options = {}) {
  const token = localStorage.getItem('token');

  const headers = {
    'Content-Type': 'application/json',
    ...options.headers
  };

  if (token && !options.skipAuth) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: 'Request failed' }));
    throw new ApiError(response.status, error.detail || 'Request failed');
  }

  return response.json();
}

// Auth
export const auth = {
  async login(email, password) {
    const formData = new FormData();
    formData.append('username', email);
    formData.append('password', password);

    const response = await fetch(`${API_BASE}/api/auth/login`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      throw new ApiError(response.status, 'Login failed');
    }

    const data = await response.json();
    localStorage.setItem('token', data.access_token);
    return data;
  },

  async register(email, password) {
    return request('/api/auth/register', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
      skipAuth: true
    });
  },

  logout() {
    localStorage.removeItem('token');
  },

  isAuthenticated() {
    return !!localStorage.getItem('token');
  }
};

// Alarms
export const alarms = {
  async list(includeDeleted = false) {
    const params = new URLSearchParams({ include_deleted: includeDeleted });
    return request(`/api/alarms?${params}`);
  },

  async get(id) {
    return request(`/api/alarms/${id}`);
  },

  async create(alarm) {
    return request('/api/alarms', {
      method: 'POST',
      body: JSON.stringify(alarm)
    });
  },

  async update(id, alarm) {
    return request(`/api/alarms/${id}`, {
      method: 'PUT',
      body: JSON.stringify(alarm)
    });
  },

  async delete(id, permanent = false) {
    const params = new URLSearchParams({ permanent });
    return request(`/api/alarms/${id}?${params}`, {
      method: 'DELETE'
    });
  }
};

// Webhooks
export const webhooks = {
  async list() {
    return request('/api/webhooks');
  },

  async create(webhook) {
    return request('/api/webhooks', {
      method: 'POST',
      body: JSON.stringify(webhook)
    });
  },

  async delete(id) {
    return request(`/api/webhooks/${id}`, {
      method: 'DELETE'
    });
  }
};

// Stats
export const stats = {
  async timeline(days = 7) {
    const params = new URLSearchParams({ days });
    return request(`/api/stats/timeline?${params}`);
  },

  async alarms() {
    return request('/api/stats/alarms');
  },

  async webhooks() {
    return request('/api/stats/webhooks');
  }
};

// WebSocket sync
export class SyncClient {
  constructor() {
    this.ws = null;
    this.handlers = [];
  }

  connect() {
    const token = localStorage.getItem('token');
    if (!token) throw new Error('Not authenticated');

    const wsUrl = `ws://localhost:8000/api/sync/ws?token=${token}`;
    this.ws = new WebSocket(wsUrl);

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.handlers.forEach(handler => handler(data));
    };

    return new Promise((resolve, reject) => {
      this.ws.onopen = () => resolve();
      this.ws.onerror = (error) => reject(error);
    });
  }

  onSync(handler) {
    this.handlers.push(handler);
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

export { ApiError };
