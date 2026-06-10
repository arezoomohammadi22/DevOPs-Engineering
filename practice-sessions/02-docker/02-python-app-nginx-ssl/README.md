# Docker Volumes & Bind Mounts — Complex Practice

## Scenario: Secure Python App Behind Nginx with SSL — No Dockerfile, No Compose

You will run a production-like stack entirely with `docker run` commands and host files:

```
[Browser] — HTTPS:443
      │
      ▼
[Nginx]  ← SSL cert from bind mount, config from bind mount
      │
      ▼
[Python App]  ← source code from bind mount, logs to named volume
      │
      ▼
[PostgreSQL]  ← data in named volume, init SQL from bind mount
```

**Constraints:**
- No Dockerfile — use only official images as-is
- No Docker Compose — only `docker run` commands
- SSL termination at Nginx using self-signed cert generated on the host
- App source code served via bind mount (live reload without rebuilding)
- DB data persisted in a named volume
- App logs written to a named volume shared between app and Nginx
- All containers on a custom bridge network

---

## Step 1 — Prepare the Project Structure

```bash
mkdir -p ~/ssl-stack/{nginx/conf,nginx/ssl,app,db-init,logs}
cd ~/ssl-stack
```

Your directory tree will look like:
```
ssl-stack/
├── nginx/
│   ├── conf/         ← nginx config (bind mount)
│   └── ssl/          ← SSL cert + key (bind mount)
├── app/              ← Python source code (bind mount)
├── db-init/          ← SQL init script (bind mount)
└── logs/             ← NOT used directly — we'll use a named volume
```

---

## Step 2 — Generate a Self-Signed SSL Certificate

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ~/ssl-stack/nginx/ssl/server.key \
  -out ~/ssl-stack/nginx/ssl/server.crt \
  -subj "/C=IR/ST=Tehran/L=Tehran/O=DevOps Course/CN=localhost"
```

Verify:
```bash
ls ~/ssl-stack/nginx/ssl/
# server.crt  server.key

openssl x509 -in ~/ssl-stack/nginx/ssl/server.crt -noout -text | grep -E "Subject:|Not After"
```

---

## Step 3 — Write the Nginx Config

```bash
cat > ~/ssl-stack/nginx/conf/default.conf << 'EOF'
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name localhost;
    return 301 https://$host$request_uri;
}

# HTTPS server
server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # Access log goes to shared volume
    access_log /var/log/app/nginx-access.log;
    error_log  /var/log/app/nginx-error.log warn;

    location / {
        proxy_pass         http://pyapp:8080;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://pyapp:8080/health;
    }
}
EOF
```

---

## Step 4 — Write the Python Application

No Dockerfile — we will use the official `python:3.12-alpine` image and install dependencies at container startup using the `-c` flag.

```bash
cat > ~/ssl-stack/app/server.py << 'EOF'
import http.server
import socketserver
import json
import os
import datetime
import psycopg2

LOG_FILE = "/var/log/app/app.log"

def log(msg):
    timestamp = datetime.datetime.utcnow().isoformat()
    line = f"[{timestamp}] {msg}\n"
    with open(LOG_FILE, "a") as f:
        f.write(line)
    print(line, end="")

def get_db_info():
    try:
        conn = psycopg2.connect(
            host=os.environ.get("DB_HOST", "postgres"),
            dbname=os.environ.get("DB_NAME", "appdb"),
            user=os.environ.get("DB_USER", "appuser"),
            password=os.environ.get("DB_PASS", "secret")
        )
        cur = conn.cursor()
        cur.execute("SELECT version(), current_database(), now();")
        row = cur.fetchone()
        conn.close()
        return {"version": row[0], "database": row[1], "time": str(row[2])}
    except Exception as e:
        return {"error": str(e)}

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        log(f"{self.command} {self.path} from {self.client_address[0]}")

        if self.path == "/health":
            body = json.dumps({"status": "ok"}).encode()
        elif self.path == "/db":
            body = json.dumps(get_db_info(), indent=2).encode()
        elif self.path == "/env":
            safe_env = {k: v for k, v in os.environ.items()
                        if not any(s in k.lower() for s in ["pass", "secret", "key"])}
            body = json.dumps(safe_env, indent=2).encode()
        else:
            body = b"<h1>Hello from Python App</h1><p>Try /db or /health</p>"

        self.send_response(200)
        self.send_header("Content-Type", "application/json" if self.path != "/" else "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # suppress default stdout logging

PORT = int(os.environ.get("PORT", 8080))
log(f"Starting server on port {PORT}")
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
EOF
```

---

## Step 5 — Write the DB Init Script

```bash
cat > ~/ssl-stack/db-init/init.sql << 'EOF'
CREATE TABLE IF NOT EXISTS visits (
    id SERIAL PRIMARY KEY,
    path VARCHAR(255),
    visited_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO visits (path) VALUES ('/init');
EOF
```

---

## Step 6 — Create Named Volumes

```bash
docker volume create pgdata       # PostgreSQL data
docker volume create applogs      # shared logs between app and nginx
```

Verify:
```bash
docker volume ls
docker volume inspect pgdata
docker volume inspect applogs
```

---

## Step 7 — Create the Network

```bash
docker network create appnet
```

---

## Step 8 — Run PostgreSQL

```bash
docker run -d \
  --name postgres \
  --network appnet \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=appdb \
  -v pgdata:/var/lib/postgresql/data \
  -v ~/ssl-stack/db-init:/docker-entrypoint-initdb.d \
  postgres:15-alpine
```

**What's happening here:**
- `pgdata` named volume → persists the database files across container restarts/removals
- `db-init/` bind mount → PostgreSQL automatically runs any `.sql` files in `/docker-entrypoint-initdb.d` on first startup

Wait for DB to be ready:
```bash
docker logs -f postgres
# Wait for: "database system is ready to accept connections"
# Press Ctrl+C to stop following
```

Verify the init script ran:
```bash
docker exec -it postgres psql -U appuser -d appdb -c "SELECT * FROM visits;"
```

Expected:
```
 id | path  |         visited_at
----+-------+----------------------------
  1 | /init | 2024-xx-xx xx:xx:xx.xxxxxx
```

---

## Step 9 — Run the Python App

No Dockerfile — we use `python:3.12-alpine` directly and install `psycopg2-binary` at startup via `sh -c`:

```bash
docker run -d \
  --name pyapp \
  --network appnet \
  -e DB_HOST=postgres \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASS=secret \
  -e PORT=8080 \
  -v ~/ssl-stack/app:/app \
  -v applogs:/var/log/app \
  python:3.12-alpine \
  sh -c "pip install psycopg2-binary --quiet && python /app/server.py"
```

**What's happening here:**
- `~/ssl-stack/app` bind mount → app reads `server.py` directly from your host. Edit the file → restart the container — no rebuild needed.
- `applogs` named volume → app writes logs to `/var/log/app/app.log` which persists and is shared.
- `sh -c` runs pip install then launches the server — no Dockerfile needed.

Check it started:
```bash
docker logs pyapp
# Expected: [timestamp] Starting server on port 8080
```

Test app directly (no SSL yet):
```bash
docker run --rm --network appnet alpine \
  sh -c "apk add --no-cache curl -q && curl -s http://pyapp:8080/"
```

---

## Step 10 — Run Nginx with SSL

```bash
docker run -d \
  --name nginx \
  --network appnet \
  -p 80:80 \
  -p 443:443 \
  -v ~/ssl-stack/nginx/conf:/etc/nginx/conf.d \
  -v ~/ssl-stack/nginx/ssl:/etc/nginx/ssl \
  -v applogs:/var/log/app \
  nginx:alpine
```

**What's happening here:**
- `nginx/conf` bind mount → Nginx reads your custom config from the host
- `nginx/ssl` bind mount → Nginx reads your SSL cert and key from the host
- `applogs` named volume → Nginx writes access/error logs to the **same** volume as the app

Test the HTTP → HTTPS redirect:
```bash
curl -v http://localhost/
# Expected: 301 redirect to https://localhost/
```

Test HTTPS (ignore self-signed cert warning):
```bash
curl -k https://localhost/
# Expected: <h1>Hello from Python App</h1>

curl -k https://localhost/health
# Expected: {"status": "ok"}

curl -k https://localhost/db
# Expected: JSON with PostgreSQL version info
```

---

## Step 11 — Verify the Shared Log Volume

Both Nginx and the Python app write to the `applogs` volume. Let's verify:

```bash
# Read logs from the volume via a temporary container
docker run --rm \
  -v applogs:/logs \
  alpine \
  sh -c "echo '=== APP LOG ===' && cat /logs/app.log && echo '=== NGINX ACCESS ===' && cat /logs/nginx-access.log"
```

You should see log entries from both services in the **same volume**.

---

## Step 12 — Test Live Code Editing (Bind Mount Power)

Edit the Python app on the host — no rebuild, no redeploy of image:

```bash
# Change the home page response
sed -i 's/Hello from Python App/Hello from LIVE EDITED App/' ~/ssl-stack/app/server.py
```

Restart just the app container (not a rebuild — just restart):
```bash
docker restart pyapp
sleep 2
curl -k https://localhost/
# Expected: <h1>Hello from LIVE EDITED App</h1>
```

Nginx didn't need to restart. The SSL config didn't change. Only the app restarted.

---

## Step 13 — Test Volume Persistence

Stop and remove all containers:
```bash
docker stop nginx pyapp postgres
docker rm nginx pyapp postgres
```

Verify volumes still exist with their data:
```bash
docker volume ls
# pgdata and applogs still listed

# Check DB data survived
docker run --rm \
  -v pgdata:/var/lib/postgresql/data \
  alpine \
  ls /var/lib/postgresql/data
# Should show PostgreSQL data files

# Check logs survived
docker run --rm \
  -v applogs:/logs \
  alpine cat /logs/app.log
# Should show previous log entries
```

Now bring everything back and confirm state is preserved:
```bash
# Re-run all three containers (same commands as before)
docker run -d --name postgres --network appnet \
  -e POSTGRES_USER=appuser -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=appdb \
  -v pgdata:/var/lib/postgresql/data \
  -v ~/ssl-stack/db-init:/docker-entrypoint-initdb.d \
  postgres:15-alpine

sleep 5

docker run -d --name pyapp --network appnet \
  -e DB_HOST=postgres -e DB_NAME=appdb -e DB_USER=appuser -e DB_PASS=secret -e PORT=8080 \
  -v ~/ssl-stack/app:/app \
  -v applogs:/var/log/app \
  python:3.12-alpine \
  sh -c "pip install psycopg2-binary --quiet && python /app/server.py"

docker run -d --name nginx --network appnet \
  -p 80:80 -p 443:443 \
  -v ~/ssl-stack/nginx/conf:/etc/nginx/conf.d \
  -v ~/ssl-stack/nginx/ssl:/etc/nginx/ssl \
  -v applogs:/var/log/app \
  nginx:alpine

sleep 3
curl -k https://localhost/db
# DB data is still there — visits table intact
```

---

## Step 14 — Rotate the SSL Certificate (Bind Mount Power)

Because the SSL cert is a bind mount, you can rotate it **without touching the container**:

```bash
# Generate a new cert
openssl req -x509 -nodes -days 730 -newkey rsa:2048 \
  -keyout ~/ssl-stack/nginx/ssl/server.key \
  -out ~/ssl-stack/nginx/ssl/server.crt \
  -subj "/C=IR/ST=Tehran/L=Tehran/O=DevOps Course v2/CN=localhost"

# Reload Nginx config (no restart, no image rebuild)
docker exec nginx nginx -s reload

# Verify new cert is active
echo | openssl s_client -connect localhost:443 2>/dev/null | \
  openssl x509 -noout -text | grep -E "Not After|O ="
```

The certificate is now rotated with zero downtime and zero image changes.

---

## Step 15 — Clean Up

```bash
docker stop nginx pyapp postgres
docker rm nginx pyapp postgres
docker network rm appnet
docker volume rm pgdata applogs
rm -rf ~/ssl-stack
```

---

## Summary

| Storage Type | Used For | Why |
|---|---|---|
| Named volume `pgdata` | PostgreSQL data files | Survives container removal |
| Named volume `applogs` | App + Nginx logs | Shared between two containers |
| Bind mount `app/` | Python source code | Live editing without rebuild |
| Bind mount `nginx/conf/` | Nginx configuration | Hot reload with `nginx -s reload` |
| Bind mount `nginx/ssl/` | SSL cert + key | Cert rotation without container changes |
| Bind mount `db-init/` | SQL init scripts | One-time DB bootstrap on first run |

**What you mastered:**
- Running a full HTTPS stack with zero Dockerfiles
- Self-signed SSL cert generation and bind-mounting into Nginx
- Sharing a named volume between two containers (logs)
- Live code editing via bind mounts
- DB persistence across full container teardown and recreation
- SSL certificate rotation with zero downtime using bind mounts
- PostgreSQL auto-initialization via the `docker-entrypoint-initdb.d` bind mount
