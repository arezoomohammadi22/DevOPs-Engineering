# Docker Networking — Complex Practice

## Scenario: Multi-Tier Web Application with Isolated Networks

You will build a 3-tier architecture:

```
[Browser]
    │
    ▼
[Nginx - Reverse Proxy]  ← public network (frontend)
    │
    ▼
[Flask App]              ← both networks (frontend + backend)
    │
    ▼
[PostgreSQL DB]          ← private network (backend only)
```

**Rules:**
- Nginx is the only container exposed to the host
- Flask can talk to both Nginx and PostgreSQL
- PostgreSQL is completely isolated from the outside — only Flask can reach it
- If you try to ping PostgreSQL from Nginx, it must fail

---

## Step 1 — Create Two Isolated Networks

```bash
docker network create frontend
docker network create backend
```

Verify:
```bash
docker network ls
```

Expected output includes:
```
NETWORK ID     NAME       DRIVER    SCOPE
xxxxxxxxxxxx   frontend   bridge    local
xxxxxxxxxxxx   backend    bridge    local
```

**Why two networks?**
Each network is an isolated broadcast domain. Containers on `frontend` cannot see containers on `backend` unless explicitly connected to both.

---

## Step 2 — Create the PostgreSQL Container (backend only)

```bash
docker run -d \
  --name postgres \
  --network backend \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine
```

Verify it started:
```bash
docker ps
docker logs postgres
```

Wait for this line in logs:
```
database system is ready to accept connections
```

**Key point:** This container is attached **only** to `backend`. Nothing on `frontend` can reach it.

---

## Step 3 — Create the Flask App

First, create a working directory:
```bash
mkdir ~/flask-app && cd ~/flask-app
```

**`app.py`:**
```python
from flask import Flask
import psycopg2
import os

app = Flask(__name__)

def get_db():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"]
    )

@app.route("/")
def index():
    return "<h2>Flask is running</h2>"

@app.route("/db")
def db_check():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT version();")
        version = cur.fetchone()[0]
        conn.close()
        return f"<h2>Connected to DB</h2><p>{version}</p>"
    except Exception as e:
        return f"<h2>DB Error</h2><p>{str(e)}</p>", 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

**`requirements.txt`:**
```
flask
psycopg2-binary
```

**`Dockerfile`:**
```dockerfile
FROM python:3.12-alpine

RUN apk add --no-cache gcc musl-dev libpq-dev

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
```

Build the image:
```bash
docker build -t flask-app .
```

Run the container — attach it to **both** networks:
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

Now connect it to `backend` as well:
```bash
docker network connect backend flask
```

Verify Flask can reach PostgreSQL:
```bash
docker exec flask ping -c 2 postgres
```

Expected: ping succeeds.

---

## Step 4 — Create the Nginx Reverse Proxy

Create an Nginx config:
```bash
mkdir ~/nginx-proxy && cd ~/nginx-proxy
```

**`nginx.conf`:**
```nginx
server {
    listen 80;

    location / {
        proxy_pass http://flask:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**`Dockerfile`:**
```dockerfile
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

Build:
```bash
docker build -t nginx-proxy .
```

Run — attach only to `frontend`, publish port 80:
```bash
docker run -d \
  --name nginx \
  --network frontend \
  -p 8080:80 \
  nginx-proxy
```

---

## Step 5 — Test the Full Stack

**Test 1 — Home route through Nginx:**
```bash
curl http://localhost:8080/
```
Expected:
```html
<h2>Flask is running</h2>
```

**Test 2 — DB route through Nginx → Flask → PostgreSQL:**
```bash
curl http://localhost:8080/db
```
Expected:
```html
<h2>Connected to DB</h2>
<p>PostgreSQL 15.x ...</p>
```

**Test 3 — Verify Nginx CANNOT reach PostgreSQL directly:**
```bash
docker exec nginx ping -c 2 postgres
```
Expected:
```
ping: bad address 'postgres'
```

This confirms the isolation is working. Nginx is on `frontend` only — it has no route to `postgres` which lives on `backend` only.

**Test 4 — Verify Flask CAN reach both:**
```bash
docker exec flask ping -c 2 postgres    # backend — should succeed
docker exec flask ping -c 2 nginx       # frontend — should succeed
```

---

## Step 6 — Inspect the Network Topology

```bash
docker network inspect frontend
```

Look at the `Containers` section — you should see only `nginx` and `flask`.

```bash
docker network inspect backend
```

You should see only `flask` and `postgres`.

This is your security boundary in action.

---

## Step 7 — Simulate a Security Test

Try to reach PostgreSQL's port directly from Nginx:
```bash
docker exec nginx sh -c "apk add --no-cache netcat-openbsd && nc -zv postgres 5432"
```
Expected:
```
nc: bad address 'postgres'
```

Now try the same from Flask:
```bash
docker exec flask sh -c "nc -zv postgres 5432"
```
Expected:
```
postgres (172.x.x.x:5432) open
```

Flask can reach the database. Nginx cannot. Network isolation is verified.

---

## Step 8 — Clean Up

```bash
docker stop nginx flask postgres
docker rm nginx flask postgres
docker rmi nginx-proxy flask-app
docker network rm frontend backend
docker volume prune -f
```

---

## Summary

| Container | Networks | Host Port |
|-----------|----------|-----------|
| nginx | frontend | 8080 → 80 |
| flask | frontend + backend | none |
| postgres | backend | none |

**What you practiced:**
- Creating multiple isolated bridge networks
- Connecting a container to more than one network
- Using container names as DNS hostnames
- Enforcing network-level isolation (DB unreachable from Nginx)
- Building a reverse proxy in front of an app container
- Verifying isolation with `ping` and `nc`

This pattern — DMZ frontend, private backend — is the foundation of secure container networking in production.
