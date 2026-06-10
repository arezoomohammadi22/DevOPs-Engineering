# Blog Platform — Docker Compose Practice

## What You Will Learn

| Concept | Details |
|---------|---------|
| Dockerfile | Multi-stage builds, non-root user, HEALTHCHECK, .dockerignore |
| Volumes | Named volumes, shared volume between containers, bind mount (dev) |
| Networks | 2 isolated networks, DNS, isolation testing |
| Docker Compose | healthcheck, depends_on, profiles, override file |

---

## Architecture

```
[Browser]
    │
    ▼ :443
[Nginx]  ─── web network ───► [blog-api :8000]
                                    │
                              ┌─────┴──────┐
                        data network    data network
                              │              │
                         [postgres]       [redis]
                              ▲              ▲
                        data network    data network
                              └─────┬──────┘
                               [image-worker]
                               (reads uploads volume)

[pgadmin :5050]  ─── data network ───► [postgres]
(profile: tools — optional)
```

### Network Access Matrix

| Container | web | data | Can reach |
|-----------|-----|------|-----------|
| nginx | ✓ | ✗ | blog-api only |
| blog-api | ✓ | ✓ | nginx + postgres + redis |
| image-worker | ✗ | ✓ | postgres + redis |
| postgres | ✗ | ✓ | — |
| redis | ✗ | ✓ | — |
| pgadmin | ✗ | ✓ | postgres only |

### Volume Map

| Volume | Used by | Purpose |
|--------|---------|---------|
| `pgdata` | postgres | DB data persistence |
| `redisdata` | redis | Redis data persistence |
| `uploads` | blog-api + image-worker | Shared file storage |
| `logs` | blog-api | App logs |
| `./nginx/ssl` (bind) | nginx | SSL cert + key |

---

## Directory Structure

```
blog-platform/
├── .env                          ← secrets
├── .dockerignore                 ← keeps images small
├── docker-compose.yml            ← main config
├── docker-compose.override.yml   ← dev overrides
│
├── blog-api/
│   ├── Dockerfile                ← multi-stage
│   ├── requirements.txt
│   └── app.py
│
├── image-worker/
│   ├── Dockerfile                ← multi-stage
│   ├── requirements.txt
│   └── worker.py
│
└── nginx/
    ├── Dockerfile
    ├── nginx.conf
    └── ssl/
        ├── server.crt
        └── server.key
```

---

## All Files

### `.env`
```env
POSTGRES_USER=bloguser
POSTGRES_PASSWORD=blogpass
POSTGRES_DB=blogdb
REDIS_PASSWORD=redispass
PGADMIN_EMAIL=admin@blog.local
PGADMIN_PASSWORD=pgadmin
```

---

### `.dockerignore`
```
__pycache__
*.pyc
*.pyo
.env
.git
*.md
```

---

### `docker-compose.yml`
```yaml
version: "3.9"

services:

  postgres:
    image: docker.arvancloud.ir/postgres:15-alpine
    container_name: postgres
    networks:
      - data
    environment:
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB:       ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      retries: 10
    restart: unless-stopped

  redis:
    image: docker.arvancloud.ir/redis:7-alpine
    container_name: redis
    command: redis-server --requirepass ${REDIS_PASSWORD}
    networks:
      - data
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      retries: 10
    restart: unless-stopped

  blog-api:
    build: ./blog-api
    container_name: blog-api
    networks:
      - web
      - data
    environment:
      DB_HOST:        postgres
      DB_NAME:        ${POSTGRES_DB}
      DB_USER:        ${POSTGRES_USER}
      DB_PASS:        ${POSTGRES_PASSWORD}
      REDIS_HOST:     redis
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    volumes:
      - uploads:/uploads
      - logs:/var/log/app
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  image-worker:
    build: ./image-worker
    container_name: image-worker
    networks:
      - data
    environment:
      REDIS_HOST:     redis
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    volumes:
      - uploads:/uploads        # same volume as blog-api
    depends_on:
      redis:
        condition: service_healthy
    restart: unless-stopped

  nginx:
    build: ./nginx
    container_name: nginx
    networks:
      - web
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - blog-api
    restart: unless-stopped

  pgadmin:
    image: docker.arvancloud.ir/dpage/pgadmin4:latest
    container_name: pgadmin
    profiles:
      - tools                   # only starts with --profile tools
    networks:
      - data
    ports:
      - "5050:80"
    environment:
      PGADMIN_DEFAULT_EMAIL:    ${PGADMIN_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD}
    depends_on:
      postgres:
        condition: service_healthy

networks:
  web:
    driver: bridge
  data:
    driver: bridge

volumes:
  pgdata:
  redisdata:
  uploads:
  logs:
```

---

### `docker-compose.override.yml`
```yaml
version: "3.9"

# Loaded automatically in development.
# In production use: docker compose -f docker-compose.yml up --build

services:
  blog-api:
    volumes:
      - ./blog-api:/app         # edit code without rebuilding
    environment:
      FLASK_DEBUG: "1"

  image-worker:
    volumes:
      - ./image-worker:/app
```

---

### `blog-api/Dockerfile`
```dockerfile
# Stage 1: install and compile packages
FROM docker.arvancloud.ir/python:3.12-alpine AS builder

RUN apk add --no-cache gcc musl-dev libpq-dev wget

WORKDIR /build
COPY requirements.txt .
RUN pip install --prefix=/install --no-cache-dir -r requirements.txt

# Stage 2: lean runtime image
FROM docker.arvancloud.ir/python:3.12-alpine

RUN apk add --no-cache libpq wget

COPY --from=builder /install /usr/local

WORKDIR /app
COPY app.py .

RUN adduser -D appuser
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:8000/health || exit 1

CMD ["python", "app.py"]
```

---

### `blog-api/requirements.txt`
```
flask
psycopg2-binary
redis
```

---

### `blog-api/app.py`
```python
import os, json, datetime, pathlib
import psycopg2, psycopg2.extras, redis
from flask import Flask, request, jsonify

app = Flask(__name__)

UPLOAD_DIR = pathlib.Path("/uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

DB = dict(host=os.environ["DB_HOST"], dbname=os.environ["DB_NAME"],
          user=os.environ["DB_USER"], password=os.environ["DB_PASS"])

def db():
    c = psycopg2.connect(**DB)
    with c.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS posts (
                id SERIAL PRIMARY KEY, title TEXT NOT NULL,
                body TEXT, created_at TIMESTAMP DEFAULT NOW()
            )""")
    c.commit()
    return c

def rdb():
    return redis.Redis(host=os.environ["REDIS_HOST"],
                       password=os.environ.get("REDIS_PASSWORD"),
                       decode_responses=True)

@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "blog-api"})

@app.route("/posts", methods=["POST"])
def create_post():
    data = request.get_json() or {}
    if not data.get("title"):
        return jsonify({"error": "title required"}), 400
    c = db()
    with c.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("INSERT INTO posts (title,body) VALUES (%s,%s) RETURNING *",
                    (data["title"], data.get("body", "")))
        post = dict(cur.fetchone())
    c.commit(); c.close()
    post["created_at"] = str(post["created_at"])
    rdb().lpush("image_jobs", json.dumps({"post_id": post["id"], "title": post["title"]}))
    return jsonify(post), 201

@app.route("/posts", methods=["GET"])
def list_posts():
    c = db()
    with c.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT * FROM posts ORDER BY id")
        posts = [dict(r) for r in cur.fetchall()]
    c.close()
    for p in posts: p["created_at"] = str(p["created_at"])
    return jsonify(posts)

@app.route("/posts/<int:id>", methods=["GET"])
def get_post(id):
    c = db()
    with c.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT * FROM posts WHERE id=%s", (id,))
        row = cur.fetchone()
    c.close()
    if not row: return jsonify({"error": "not found"}), 404
    row = dict(row); row["created_at"] = str(row["created_at"])
    return jsonify(row)

@app.route("/posts/<int:id>", methods=["DELETE"])
def delete_post(id):
    c = db()
    with c.cursor() as cur:
        cur.execute("DELETE FROM posts WHERE id=%s RETURNING id", (id,))
        deleted = cur.fetchone()
    if not deleted: c.close(); return jsonify({"error": "not found"}), 404
    c.commit(); c.close()
    return jsonify({"deleted": id})

@app.route("/uploads")
def list_uploads():
    files = [f.name for f in UPLOAD_DIR.iterdir() if f.is_file()]
    return jsonify({"files": files})

@app.route("/queue")
def queue_status():
    r = rdb()
    return jsonify({"pending_jobs": r.llen("image_jobs"),
                    "processed_jobs": int(r.get("processed_jobs") or 0)})

app.run(host="0.0.0.0", port=8000)
```

---

### `image-worker/Dockerfile`
```dockerfile
# Stage 1: build (needs gcc for Pillow)
FROM docker.arvancloud.ir/python:3.12-alpine AS builder

RUN apk add --no-cache gcc musl-dev jpeg-dev zlib-dev libffi-dev

WORKDIR /build
COPY requirements.txt .
RUN pip install --prefix=/install --no-cache-dir -r requirements.txt

# Stage 2: runtime only
FROM docker.arvancloud.ir/python:3.12-alpine

RUN apk add --no-cache jpeg

COPY --from=builder /install /usr/local

WORKDIR /app
COPY worker.py .

RUN adduser -D workeruser
USER workeruser

CMD ["python", "worker.py"]
```

---

### `image-worker/requirements.txt`
```
redis
psycopg2-binary
Pillow
```

---

### `image-worker/worker.py`
```python
import os, json, datetime, pathlib
import redis
from PIL import Image, ImageDraw

UPLOAD_DIR = pathlib.Path("/uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

def rdb():
    return redis.Redis(host=os.environ["REDIS_HOST"],
                       password=os.environ.get("REDIS_PASSWORD"),
                       decode_responses=True)

def log(msg):
    print(f"[{datetime.datetime.utcnow().isoformat()}] [worker] {msg}", flush=True)

def process_job(job):
    data    = json.loads(job)
    post_id = data["post_id"]
    title   = data["title"]
    img  = Image.new("RGB", (400, 200), color=(70, 130, 180))
    draw = ImageDraw.Draw(img)
    draw.text((20, 80),  f"Post #{post_id}", fill="white")
    draw.text((20, 110), title[:40],          fill="white")
    path = UPLOAD_DIR / f"post_{post_id}.png"
    img.save(path)
    log(f"Thumbnail created: {path}")

def main():
    log("Worker started, waiting for jobs...")
    r = rdb()
    while True:
        job = r.brpop("image_jobs", timeout=5)
        if job:
            _, payload = job
            try:
                process_job(payload)
                r.incr("processed_jobs")
            except Exception as e:
                log(f"Error: {e}")

main()
```

---

### `nginx/Dockerfile`
```dockerfile
FROM docker.arvancloud.ir/nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80 443
```

---

### `nginx/nginx.conf`
```nginx
server {
    listen 80;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    location /api/ {
        rewrite ^/api/(.*)$ /$1 break;
        proxy_pass          http://blog-api:8000;
        proxy_set_header    Host              $host;
        proxy_set_header    X-Real-IP         $remote_addr;
        proxy_set_header    X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://blog-api:8000/health;
    }
}
```

---

## Generate SSL Certificate

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/server.key \
  -out    nginx/ssl/server.crt \
  -subj "/C=IR/ST=Tehran/O=Blog Platform/CN=localhost" 2>/dev/null
```

---

## Start

```bash
docker compose up --build
```

---

## Stop

```bash
docker compose down          # keep data
docker compose down -v       # delete all volumes too
```

---

## Test

```bash
# Health
curl -k https://localhost/health

# Create post (also queues a thumbnail job)
curl -k -X POST https://localhost/api/posts \
  -H "Content-Type: application/json" \
  -d '{"title":"My Post","body":"Hello Docker!"}'

# List posts
curl -k https://localhost/api/posts

# Get one post
curl -k https://localhost/api/posts/1

# Delete post
curl -k -X DELETE https://localhost/api/posts/1

# Check Redis queue
curl -k https://localhost/api/queue

# Check shared uploads volume (worker thumbnails)
curl -k https://localhost/api/uploads
```

---

## Verify Network Isolation

```bash
docker exec nginx        ping -c1 postgres     # FAIL — different network
docker exec nginx        ping -c1 redis        # FAIL — different network
docker exec blog-api     ping -c1 postgres     # OK
docker exec blog-api     ping -c1 redis        # OK
docker exec image-worker ping -c1 nginx        # FAIL — not on web network
docker exec image-worker ping -c1 redis        # OK
```

---

## Optional: pgadmin

```bash
docker compose --profile tools up -d pgadmin
```

Open browser: `http://localhost:5050`
Login: `admin@blog.local` / `pgadmin`
Connect to host: `postgres`, user: `bloguser`, password: `blogpass`

---

## Inspect Volumes

```bash
# List volumes
docker volume ls

# See files in shared uploads volume
docker run --rm \
  -v blog-platform_uploads:/uploads \
  docker.arvancloud.ir/alpine \
  ls -la /uploads
```

---

## Summary

| Service | Networks | Volumes |
|---------|----------|---------|
| nginx | web | ssl (bind, read-only) |
| blog-api | web + data | uploads + logs (named) |
| image-worker | data | uploads (shared with api) |
| postgres | data | pgdata (named) |
| redis | data | redisdata (named) |
| pgadmin | data | — (profile: tools) |
