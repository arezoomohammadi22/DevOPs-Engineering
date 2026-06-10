# Docker Networking Practice — docker run

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

## Step 1 — Create Networks

```bash
docker network create frontend
docker network create backend
```

Verify:
```bash
docker network ls
```

---

## Step 2 — Start PostgreSQL

```bash
docker run -d \
  --name postgres \
  --network backend \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=appdb \
  -v pgdata:/var/lib/postgresql/data \
  docker.arvancloud.ir/postgres:15-alpine
```

Wait until ready:
```bash
docker logs postgres
# wait for: "database system is ready to accept connections"
```

---

## Step 3 — Build and Start Flask

```bash
cd flask-app
docker build -t flask-app .
cd ..
```

```bash
docker run -d \
  --name flask \
  --network frontend \
  -e DB_HOST=postgres \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASS=secret \
  flask-app
```

Connect flask to backend network too:
```bash
docker network connect backend flask
```

---

## Step 4 — Build and Start Nginx

```bash
cd nginx-proxy
docker build -t nginx-proxy .
cd ..
```

```bash
docker run -d \
  --name nginx \
  --network frontend \
  -p 8080:80 \
  nginx-proxy
```

---

## Test

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
# Should show only nginx + flask
docker network inspect frontend

# Should show only flask + postgres
docker network inspect backend
```

---

## Clean Up

```bash
docker stop nginx flask postgres
docker rm nginx flask postgres
docker rmi nginx-proxy flask-app
docker network rm frontend backend
docker volume rm pgdata
```
