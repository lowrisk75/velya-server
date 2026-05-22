# Velya Remote Server

Backend API + web dashboard for Velya smart alarm remote management.

## Features

- **Remote Alarm Management**: CRUD operations for alarms from any device
- **Bidirectional Sync**: Real-time synchronization with iOS app
- **Webhook Automation**: External control via HTTP webhooks (Home Assistant, Node-RED, etc.)
- **Statistics & Analytics**: Timeline visualization, usage patterns, webhook metrics
- **Multi-Device Support**: Conflict resolution with last-write-wins strategy

## Architecture

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│  iOS App    │◄────►│  FastAPI     │◄────►│ PostgreSQL  │
│  (Velya)    │ JWT  │  Backend     │      │  Database   │
└─────────────┘      └──────────────┘      └─────────────┘
       │                    │                      │
       │                    │                      │
       │              ┌─────▼─────┐         ┌──────▼──────┐
       │              │   Redis   │         │  WebSocket  │
       │              │ Rate Limit│         │  Real-time  │
       │              └───────────┘         └─────────────┘
       │
       │
┌──────▼──────┐      ┌──────────────┐
│ Home        │      │  Web         │
│ Assistant   │─────►│  Dashboard   │
│ Webhooks    │      │  (Svelte 5)  │
└─────────────┘      └──────────────┘
```

## Tech Stack

**Backend:**
- FastAPI (async Python web framework)
- PostgreSQL (primary database)
- SQLAlchemy 2.0 (async ORM)
- Redis (rate limiting + pub/sub)
- JWT authentication
- WebSocket support

**Frontend:**
- Svelte 5 (reactive UI)
- Vite (build tool)
- TailwindCSS (styling)
- Chart.js (timeline visualization)

## Installation

### Prerequisites

- Python 3.11+
- PostgreSQL 14+
- Redis 7+
- Node.js 20+ (for frontend)

### Backend Setup

1. Clone repository:
```bash
cd ~/GitHub
git clone <repo-url> velya-server
cd velya-server
```

2. Create virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

3. Install dependencies:
```bash
pip install -r backend/requirements.txt
```

4. Configure environment:
```bash
cp .env.example .env
# Edit .env with your settings
```

5. Initialize database:
```bash
# Run migrations (when Alembic is set up)
alembic upgrade head
```

6. Start server:
```bash
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

### Frontend Setup

1. Install dependencies:
```bash
cd frontend
npm install
```

2. Configure API endpoint:
```bash
cp .env.example .env
# Set VITE_API_URL=http://localhost:8000
```

3. Start dev server:
```bash
npm run dev
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Create new user account
- `POST /api/auth/login` - Login and get JWT token

### Alarms
- `GET /api/alarms` - List all alarms
- `POST /api/alarms` - Create new alarm
- `GET /api/alarms/{id}` - Get specific alarm
- `PUT /api/alarms/{id}` - Update alarm
- `DELETE /api/alarms/{id}` - Delete alarm (soft delete)

### Webhooks
- `GET /api/webhooks` - List webhooks
- `POST /api/webhooks` - Create webhook
- `DELETE /api/webhooks/{id}` - Delete webhook
- `POST /webhook/trigger/{webhook_id}` - Public trigger endpoint (no auth, uses verification code)

### Sync
- `POST /api/sync/push` - Push device changes to server
- `GET /api/sync/pull?since={timestamp}` - Pull server changes since timestamp
- `WS /api/sync/ws?token={jwt}` - Real-time sync WebSocket

### Statistics
- `GET /api/stats/timeline?days=7` - Get scheduled alarms timeline
- `GET /api/stats/alarms` - Get alarm analytics
- `GET /api/stats/webhooks` - Get webhook metrics

## Configuration

Create `.env` file with:

```env
# Database
DATABASE_URL=postgresql+asyncpg://velya:password@localhost/velya

# Redis
REDIS_URL=redis://localhost:6379

# Security
SECRET_KEY=your-secret-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=43200  # 30 days

# CORS
CORS_ORIGINS=["http://localhost:5173","https://velya.kevinn.ie"]

# App
APP_NAME=Velya Server
VERSION=1.0.0
```

## Deployment

### LXC Container (Proxmox)

1. Create LXC container (Ubuntu 22.04)
2. Install dependencies
3. Clone repository
4. Set up systemd service:

```ini
[Unit]
Description=Velya API Server
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=velya
WorkingDirectory=/opt/velya-server
Environment="PATH=/opt/velya-server/venv/bin"
ExecStart=/opt/velya-server/venv/bin/uvicorn backend.main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
```

4. Configure Nginx reverse proxy
5. Set up Cloudflare Tunnel for public access

## Webhook Usage

### Create Webhook

```bash
curl -X POST https://velya.kevinn.ie/api/webhooks \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Morning Alarm",
    "alarm_id": 123
  }'
```

Response includes `webhook_id` and `verification_code`.

### Trigger from Home Assistant

```yaml
automation:
  - alias: "Disable Velya Alarm on Vacation"
    trigger:
      - platform: state
        entity_id: input_boolean.vacation_mode
        to: "on"
    action:
      - service: rest_command.velya_disable_alarm
        
rest_command:
  velya_disable_alarm:
    url: "https://velya.kevinn.ie/webhook/trigger/YOUR_WEBHOOK_ID"
    method: POST
    headers:
      Content-Type: application/json
      X-Verification-Code: YOUR_VERIFICATION_CODE
    payload: |
      {
        "action": "disable"
      }
```

## Sync Protocol

### Last-Write-Wins Conflict Resolution

1. iOS app pushes changes with timestamp
2. Server compares with existing `last_modified_at`
3. If client timestamp < server timestamp → conflict, server wins
4. Otherwise, apply change and log to `SyncEvent` table
5. All devices pull changes since last sync

### WebSocket Real-Time Sync

- Connect with JWT token
- Server broadcasts changes to all user's connected devices
- Reduces sync latency from polling to instant

## Security

- JWT tokens expire after 30 days
- Passwords hashed with bcrypt
- Rate limiting: 10 requests/minute per webhook
- Webhook verification codes are cryptographically secure (32 bytes)
- All webhook triggers logged for audit

## Development

### Database Migrations

```bash
# Create migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

### Running Tests

```bash
pytest tests/
```

## License

Proprietary - LorisLabs
