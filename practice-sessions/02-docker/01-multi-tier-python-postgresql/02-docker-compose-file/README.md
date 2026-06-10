# Docker Networking — Multi-Tier Web Application

## Architecture

```
                        ┌─────────────────────────────────────────────┐
                        │               HOST MACHINE                  │
                        │                                             │
  [Browser]             │  ┌──────────────────────────────────────┐  │
      │                 │  │          FRONTEND NETWORK            │  │
      │ :8080           │  │                                      │  │
      ▼                 │  │  ┌─────────────┐   ┌─────────────┐  │  │
  ────────────  ──────────►│  │    nginx     │──►│    flask    │  │  │
  port 8080:80          │  │  │ reverse proxy│   │   app :5000 │  │  │
                        │  │  └─────────────┘   └──────┬──────┘  │  │
                        │  └──────────────────────────│──────────┘  │
                        │                             │              │
                        │  ┌──────────────────────────▼──────────┐  │
                        │  │           BACKEND NETWORK            │  │
                        │  │                                      │  │
                        │  │              ┌─────────────┐         │  │
                        │  │              │  postgres   │         │  │
                        │  │              │   DB :5432  │         │  │
                        │  │              └─────────────┘         │  │
                        │  └──────────────────────────────────────┘  │
                        └─────────────────────────────────────────────┘

Network Access Matrix:
  nginx    → flask   ✓  (same frontend network)
  flask    → nginx   ✓  (same frontend network)
  flask    → postgres✓  (same backend network)
  nginx    → postgres✗  (different networks — isolated)
  host     → nginx   ✓  (port 8080 published)
  host     → flask   ✗  (no port published)
  host     → postgres✗  (no port published)
```

---

## Directory Structure

```
docker-networking-practice/
├── docker-compose.yml          # Orchestrates all three services
├── .env                        # Environment variables (never commit secrets)
├── README.md                   # This file
│
├── flask-app/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py
│
└── nginx-proxy/
    ├── Dockerfile
    └── nginx.conf
```

---

## File Contents

### `docker-compose.yml`

```yaml
version: "3.9"

services:

  nginx:
    build:
      context: ./nginx-proxy
    container_name: nginx
    ports:
      - "8080:80"
    networks:
      - frontend
    depends_on:
      flask:
        condition: service_healthy
    restart: unless-stopped

  flask:
    build:
      context: ./flask-app
    container_name: flask
    networks:
      - frontend
      - backend
    environment:
      DB_HOST: postgres
      DB_NAME: ${POSTGRES_DB}
      DB_USER: ${POSTGRES_USER}
      DB_PASS: ${POSTGRES_PASSWORD}
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5000/"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    container_name: postgres
    networks:
      - backend
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge

volumes:
  pgdata:
```

---

### `.env`

```env
POSTGRES_USER=appuser
POSTGRES_PASSWORD=secret
POSTGRES_DB=appdb
```

> **Never commit `.env` to version control.** Add it to `.gitignore`.

---

### `flask-app/app.py`

```python
from flask import Flask
import psycopg2
import os

app = Flask(__name__)


def get_db():
    """Open a new DB connection. Caller is responsible for closing it."""
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
    )


@app.route("/")
def index():
    return "<h2>Flask is running</h2>"


@app.route("/db")
def db_check():
    conn = None
    try:
        conn = get_db()
        with conn.cursor() as cur:
            cur.execute("SELECT version();")
            version = cur.fetchone()[0]
        return f"<h2>Connected to DB</h2><p>{version}</p>"
    except Exception as e:
        return f"<h2>DB Error</h2><p>{str(e)}</p>", 500
    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

**Improvements over original:**
- `conn.close()` is now in a `finally` block — connection always closes, even on error
- Uses context manager `with conn.cursor()` so the cursor closes cleanly

---

### `flask-app/requirements.txt`

```
flask==3.0.3
psycopg2-binary==2.9.9
```

> Pin versions so builds are reproducible.

---

### `flask-app/Dockerfile`

```dockerfile
FROM python:3.12-alpine

# Build deps for psycopg2
RUN apk add --no-cache gcc musl-dev libpq-dev

WORKDIR /app

# Install dependencies first (better layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

# Use a non-root user
RUN adduser -D appuser
USER appuser

CMD ["python", "app.py"]
```

**Improvements over original:**
- `--no-cache-dir` keeps the image smaller
- Non-root user (`appuser`) — best practice for production

---

### `nginx-proxy/nginx.conf`

```nginx
server {
    listen 80;

    # Pass all requests to Flask
    location / {
        proxy_pass         http://flask:5000;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;

        # Return a clean 502 if Flask is down instead of hanging
        proxy_connect_timeout  5s;
        proxy_read_timeout     10s;
    }

    # Health check endpoint — doesn't hit Flask
    location /health {
        return 200 "nginx ok\n";
        add_header Content-Type text/plain;
    }
}
```

**Improvements over original:**
- `X-Forwarded-For` header so Flask sees real client IPs
- Timeouts so a crashed Flask returns 502 quickly instead of hanging
- `/health` endpoint for the proxy itself

---

### `nginx-proxy/Dockerfile`

```dockerfile
FROM nginx:alpine

# Remove the default config
RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
```

---

## Usage

### Start the full stack

```bash
docker compose up --build
```

Add `-d` to run in the background:

```bash
docker compose up --build -d
```

### Tear down (keep data)

```bash
docker compose down
```

### Tear down and delete all data

```bash
docker compose down -v
```

---

## Testing

### Test 1 — Home route

```bash
curl http://localhost:8080/
```

Expected: `<h2>Flask is running</h2>`

### Test 2 — Database route

```bash
curl http://localhost:8080/db
```

Expected: `<h2>Connected to DB</h2><p>PostgreSQL 15.x ...</p>`

### Test 3 — Nginx health endpoint

```bash
curl http://localhost:8080/health
```

Expected: `nginx ok`

### Test 4 — Verify Nginx CANNOT reach PostgreSQL

```bash
docker exec nginx ping -c 2 postgres
```

Expected: `ping: bad address 'postgres'`

### Test 5 — Verify Flask CAN reach both

```bash
docker exec flask ping -c 2 postgres   # backend — should succeed
docker exec flask ping -c 2 nginx      # frontend — should succeed
```

### Test 6 — Port-level isolation from Nginx

```bash
docker exec nginx sh -c "apk add --no-cache netcat-openbsd 2>/dev/null && nc -zv postgres 5432"
```

Expected: `nc: bad address 'postgres'`

### Test 7 — Port-level access from Flask

```bash
docker exec flask sh -c "nc -zv postgres 5432"
```

Expected: `postgres (172.x.x.x:5432) open`

### Test 8 — Data persistence (volumes)

```bash
# Start fresh, write some data
docker compose up -d
curl http://localhost:8080/db

# Restart postgres only
docker compose restart postgres

# Data still there
curl http://localhost:8080/db
```

---

## Inspect Network Topology

```bash
# See only nginx + flask
docker network inspect docker-networking-practice_frontend

# See only flask + postgres
docker network inspect docker-networking-practice_backend
```

---

## What Changed From Manual Setup

| Aspect | Manual (`docker run`) | Compose |
|--------|----------------------|---------|
| Startup | 8+ commands, order matters | `docker compose up` |
| Network creation | Manual `docker network create` | Declared in `networks:` |
| Multi-network container | Separate `docker network connect` | Listed under `networks:` in service |
| Health checks | Manual polling | `healthcheck:` + `depends_on: condition` |
| Secrets | Hardcoded in flags | `.env` file |
| Data persistence | Lost on `docker rm` | Named volume `pgdata` |
| Restart on crash | None | `restart: unless-stopped` |

---

## Security Boundary Summary

| Container | Networks | Host Port | Reaches |
|-----------|----------|-----------|---------|
| nginx | frontend | 8080 → 80 | flask only |
| flask | frontend + backend | none | nginx + postgres |
| postgres | backend | none | nothing (only receives) |

**Key principle:** PostgreSQL has no route to the outside world. Even if the Flask app were compromised, an attacker cannot reach the database directly from outside — they must go through Flask's code path first.

---

## Next Steps to Explore

- **Add SSL** — terminate TLS at Nginx with a self-signed cert
- **Connection pooling** — replace direct psycopg2 with `psycopg2` pool or switch Flask to SQLAlchemy
- **Secrets management** — replace `.env` with Docker secrets or Vault
- **Resource limits** — add `mem_limit` and `cpus` to each service
- **Logging** — add a centralised log driver (e.g., `json-file` with rotation or a Loki sidecar)
