# Docker Networking Practice — Docker Compose

## Architecture

```
[Browser]
    │
    ▼
[Nginx :8080]  ──── frontend network ────  [Flask :5000]
                                                │
                                         backend network
                                                │
                                          [Postgres :5432]
```

| Container | Networks           | Host Port |
|-----------|--------------------|-----------|
| nginx     | frontend           | 8080 → 80 |
| flask     | frontend + backend | none      |
| postgres  | backend            | none      |

---

## Directory Structure

```
docker-networking-practice/
├── docker-compose.yml
├── .env
├── test.sh
├── flask-app/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── app.py
└── nginx-proxy/
    ├── Dockerfile
    └── nginx.conf
```

---

## Files

### `.env`
```env
POSTGRES_USER=appuser
POSTGRES_PASSWORD=secret
POSTGRES_DB=appdb
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
      - backend
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      retries: 10

  flask:
    build: ./flask-app
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
      start_period: 30s
    restart: on-failure

  nginx:
    build: ./nginx-proxy
    container_name: nginx
    ports:
      - "8080:80"
    networks:
      - frontend
    depends_on:
      - flask
    restart: unless-stopped

networks:
  frontend:
  backend:

volumes:
  pgdata:
```

---

### `flask-app/Dockerfile`
```dockerfile
FROM docker.arvancloud.ir/python:3.12-alpine

RUN apk add --no-cache gcc musl-dev libpq-dev wget

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .

CMD ["python", "app.py"]
```

### `flask-app/requirements.txt`
```
flask
psycopg2-binary
```

### `flask-app/app.py`
```python
import os
import psycopg2
import psycopg2.extras
from flask import Flask, request, jsonify

app = Flask(__name__)

DB = dict(
    host=os.environ["DB_HOST"],
    dbname=os.environ["DB_NAME"],
    user=os.environ["DB_USER"],
    password=os.environ["DB_PASS"],
)

def conn():
    return psycopg2.connect(**DB)

def ensure_table(c):
    with c.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)
    c.commit()

@app.route("/")
def index():
    return jsonify({"status": "ok"})

@app.route("/items", methods=["POST"])
def create():
    data = request.get_json() or {}
    if not data.get("name"):
        return jsonify({"error": "name is required"}), 400
    c = conn(); ensure_table(c)
    with c.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(
            "INSERT INTO items (name, description) VALUES (%s,%s) RETURNING *",
            (data["name"], data.get("description"))
        )
        row = dict(cur.fetchone())
    c.commit(); c.close()
    row["created_at"] = str(row["created_at"])
    return jsonify(row), 201

@app.route("/items", methods=["GET"])
def list_all():
    c = conn(); ensure_table(c)
    with c.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT * FROM items ORDER BY id")
        rows = [dict(r) for r in cur.fetchall()]
    c.close()
    for r in rows: r["created_at"] = str(r["created_at"])
    return jsonify(rows)

@app.route("/items/<int:id>", methods=["GET"])
def get_one(id):
    c = conn()
    with c.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT * FROM items WHERE id=%s", (id,))
        row = cur.fetchone()
    c.close()
    if not row: return jsonify({"error": "not found"}), 404
    row = dict(row); row["created_at"] = str(row["created_at"])
    return jsonify(row)

@app.route("/items/<int:id>", methods=["PUT"])
def update(id):
    data = request.get_json() or {}
    c = conn()
    with c.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(
            "UPDATE items SET name=COALESCE(%s,name), description=COALESCE(%s,description) WHERE id=%s RETURNING *",
            (data.get("name"), data.get("description"), id)
        )
        row = cur.fetchone()
    if not row: c.close(); return jsonify({"error": "not found"}), 404
    c.commit(); c.close()
    row = dict(row); row["created_at"] = str(row["created_at"])
    return jsonify(row)

@app.route("/items/<int:id>", methods=["DELETE"])
def delete(id):
    c = conn()
    with c.cursor() as cur:
        cur.execute("DELETE FROM items WHERE id=%s RETURNING id", (id,))
        deleted = cur.fetchone()
    if not deleted: c.close(); return jsonify({"error": "not found"}), 404
    c.commit(); c.close()
    return jsonify({"deleted": id})

app.run(host="0.0.0.0", port=5000)
```

---

### `nginx-proxy/Dockerfile`
```dockerfile
FROM docker.arvancloud.ir/nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

### `nginx-proxy/nginx.conf`
```nginx
server {
    listen 80;
    location / {
        proxy_pass http://flask:5000;
        proxy_set_header Host $host;
    }
    location /health {
        return 200 "nginx ok\n";
        add_header Content-Type text/plain;
    }
}
```

---

## Start

```bash
docker compose up --build
```

## Stop

```bash
docker compose down        # keep data
docker compose down -v     # delete data too
```

---

## Test

```bash
bash test.sh
```

Or manually with curl:

```bash
# Health
curl http://localhost:8080/
curl http://localhost:8080/health

# Create
curl -X POST http://localhost:8080/items \
  -H "Content-Type: application/json" \
  -d '{"name":"apple","description":"a red fruit"}'

# List all
curl http://localhost:8080/items

# Get one
curl http://localhost:8080/items/1

# Update
curl -X PUT http://localhost:8080/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"green apple"}'

# Delete
curl -X DELETE http://localhost:8080/items/1
```

---

## Verify Network Isolation

```bash
# Nginx CANNOT reach postgres (should fail)
docker exec nginx ping -c 2 postgres

# Flask CAN reach postgres (should succeed)
docker exec flask ping -c 2 postgres

# Flask CAN reach nginx (should succeed)
docker exec flask ping -c 2 nginx
```

---

## Inspect Networks

```bash
docker network inspect docker-networking-practice_frontend
docker network inspect docker-networking-practice_backend
```
