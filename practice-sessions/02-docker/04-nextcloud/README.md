# Nextcloud — Production Deployment with Docker Compose

## Quick Start

```bash
bash nextcloud-run.sh        # create all files + start (first time)
bash nextcloud-run.sh start  # start after reboot
bash nextcloud-run.sh stop   # stop containers
bash nextcloud-run.sh logs   # watch logs
bash nextcloud-run.sh status # check health
bash nextcloud-run.sh clean  # delete everything
```

### Access from your laptop via SSH tunnel

```bash
# Run this on your laptop
ssh -L 9443:localhost:443 backend-haproxy
```

Then open: **https://localhost:9443**

```
Laptop:9443 ── SSH tunnel ──► backend-haproxy:443 ──► nc-nginx:443
```

> Use `-fN` to keep tunnel in background: `ssh -fNL 9443:localhost:443 backend-haproxy`
> Close it with: `pkill -f "ssh -fNL 9443"`

---

## Stack

| Service | Image | Role |
|---------|-------|------|
| nextcloud | nextcloud:28-fpm-alpine | App (PHP-FPM) |
| nginx | nginx:alpine | Reverse proxy + SSL |
| postgres | postgres:15-alpine | Database |
| redis | redis:7-alpine | Cache + file locking |
| cron | nextcloud:28-fpm-alpine | Background jobs |

**Why FPM and not the all-in-one image?**
- `nextcloud:fpm-alpine` is smaller, faster, and separates concerns
- Nginx handles SSL, compression, static files — Apache does not need to be in the container
- Cron runs as its own container so it doesn't block the web process
- You control each component independently

---

## Architecture

```
[Browser]
    │
    ▼ :443 / :80
[Nginx]  ─── frontend network ───► [Nextcloud FPM :9000]
  SSL                                      │
  static files                      ┌──────┴───────┐
  headers                     backend network   backend network
                                     │               │
                                [PostgreSQL]       [Redis]
                                  (data)        (cache + locks)

[Cron]  ─── backend network (same image as nextcloud, runs jobs every 5 min)
```

### Network Isolation

| Container | frontend | backend |
|-----------|----------|---------|
| nginx | ✓ | ✗ |
| nextcloud | ✓ | ✓ |
| cron | ✗ | ✓ |
| postgres | ✗ | ✓ |
| redis | ✗ | ✓ |

---

## Directory Structure

```
nextcloud/
├── .env
├── .gitignore
├── docker-compose.yml
└── nginx/
    ├── nginx.conf
    └── ssl/
        ├── server.crt       ← self-signed (dev) or Let's Encrypt (prod)
        └── server.key
```

---

## Step 1 — Create Directories

```bash
mkdir -p nextcloud/nginx/ssl
cd nextcloud
```

---

## Step 2 — `.env`

```env
# Database
POSTGRES_USER=nextclouduser
POSTGRES_PASSWORD=StrongPassw0rd!
POSTGRES_DB=nextclouddb

# Redis
REDIS_PASSWORD=RedisStrongPass!

# Nextcloud admin account (first run only)
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=AdminStrongPass!

# Your domain or IP
NEXTCLOUD_TRUSTED_DOMAIN=localhost

# PHP memory limit
PHP_MEMORY_LIMIT=1024M
PHP_UPLOAD_LIMIT=10G
```

> Never commit `.env` to version control.

---

## Step 3 — Generate SSL Certificate

### Option A — Self-signed (local / testing)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/server.key \
  -out    nginx/ssl/server.crt \
  -subj "/C=IR/ST=Tehran/O=Nextcloud/CN=localhost" 2>/dev/null
```

### Option B — Let's Encrypt (production, requires a real domain)

```bash
# Install certbot on the host
certbot certonly --standalone -d yourdomain.com

# Copy certs to your ssl folder
cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/server.crt
cp /etc/letsencrypt/live/yourdomain.com/privkey.pem   nginx/ssl/server.key
```

---

## Step 4 — `nginx/nginx.conf`

```nginx
upstream nextcloud_fpm {
    server nextcloud:9000;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name localhost;

    # SSL
    ssl_certificate     /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    # Upload size — must match PHP_UPLOAD_LIMIT
    client_max_body_size 10G;
    client_body_timeout  300s;

    # Security headers (Nextcloud best practice)
    add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
    add_header X-Content-Type-Options    "nosniff"                              always;
    add_header X-Frame-Options           "SAMEORIGIN"                           always;
    add_header X-Permitted-Cross-Domain-Policies "none"                         always;
    add_header X-Robots-Tag              "noindex, nofollow"                    always;
    add_header X-XSS-Protection          "1; mode=block"                        always;
    add_header Referrer-Policy           "no-referrer"                          always;

    # Remove X-Powered-By
    fastcgi_hide_header X-Powered-By;

    root /var/www/html;
    index index.php index.html;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_types application/atom+xml text/javascript application/javascript
               application/json application/ld+json application/manifest+json
               application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject
               application/wasm application/x-font-ttf application/x-web-app-manifest+json
               application/xhtml+xml application/xml font/opentype image/bmp
               image/svg+xml image/x-icon text/cache-manifest text/css text/plain
               text/vcard text/vnd.rim.location.xloc text/vtt text/x-component
               text/x-cross-domain-policy;

    # CalDAV / CardDAV redirects
    location = /.well-known/carddav {
        return 301 $scheme://$host/remote.php/dav;
    }
    location = /.well-known/caldav {
        return 301 $scheme://$host/remote.php/dav;
    }
    location = /.well-known/webfinger {
        return 301 $scheme://$host/index.php/.well-known/webfinger;
    }
    location = /.well-known/nodeinfo {
        return 301 $scheme://$host/index.php/.well-known/nodeinfo;
    }

    # Deny access to sensitive files
    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:$|/) {
        return 404;
    }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
        return 404;
    }

    # Static files with caching
    location ~ \.(?:css|js|woff2?|svg|gif|map|png|html|ttf|ico|jpg|jpeg)$ {
        try_files $uri /index.php$request_uri;
        expires 6M;
        access_log off;
    }

    # PHP via FPM
    location ~ \.php(?:$|/) {
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        set $path_info $fastcgi_path_info;
        try_files $fastcgi_script_name =404;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO       $path_info;
        fastcgi_param HTTPS           on;
        fastcgi_param modHeadersAvailable true;
        fastcgi_param front_controller_active true;
        fastcgi_pass   nextcloud_fpm;
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
        fastcgi_read_timeout 300;
    }

    location / {
        try_files $uri $uri/ /index.php$request_uri;
    }
}
```

---

## Step 5 — `docker-compose.yml`

```yaml
version: "3.9"

services:

  postgres:
    image: docker.arvancloud.ir/postgres:15-alpine
    container_name: nc-postgres
    networks:
      - backend
    environment:
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB:       ${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  redis:
    image: docker.arvancloud.ir/redis:7-alpine
    container_name: nc-redis
    command: >
      redis-server
      --requirepass ${REDIS_PASSWORD}
      --maxmemory 512mb
      --maxmemory-policy allkeys-lru
    networks:
      - backend
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  nextcloud:
    image: docker.arvancloud.ir/nextcloud:28-fpm-alpine
    container_name: nc-app
    networks:
      - frontend
      - backend
    environment:
      # Database
      POSTGRES_HOST:     postgres
      POSTGRES_DB:       ${POSTGRES_DB}
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      # Redis
      REDIS_HOST:          redis
      REDIS_HOST_PASSWORD: ${REDIS_PASSWORD}
      # Admin
      NEXTCLOUD_ADMIN_USER:     ${NEXTCLOUD_ADMIN_USER}
      NEXTCLOUD_ADMIN_PASSWORD: ${NEXTCLOUD_ADMIN_PASSWORD}
      # Trusted domain
      NEXTCLOUD_TRUSTED_DOMAINS: ${NEXTCLOUD_TRUSTED_DOMAIN}
      # PHP limits
      PHP_MEMORY_LIMIT: ${PHP_MEMORY_LIMIT}
      PHP_UPLOAD_LIMIT: ${PHP_UPLOAD_LIMIT}
    volumes:
      - nextcloud_data:/var/www/html             # all Nextcloud files
      - nextcloud_config:/var/www/html/config     # config.php
      - nextcloud_apps:/var/www/html/custom_apps  # installed apps
      - nextcloud_themes:/var/www/html/themes     # custom themes
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  cron:
    image: docker.arvancloud.ir/nextcloud:28-fpm-alpine
    container_name: nc-cron
    networks:
      - backend
    entrypoint: /cron.sh         # runs Nextcloud background jobs every 5 min
    volumes:
      - nextcloud_data:/var/www/html
      - nextcloud_config:/var/www/html/config
      - nextcloud_apps:/var/www/html/custom_apps
    depends_on:
      - nextcloud
    restart: unless-stopped

  nginx:
    image: docker.arvancloud.ir/nginx:alpine
    container_name: nc-nginx
    networks:
      - frontend
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - nextcloud_data:/var/www/html:ro    # serve static files directly
    depends_on:
      - nextcloud
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge

volumes:
  pgdata:
  redisdata:
  nextcloud_data:
  nextcloud_config:
  nextcloud_apps:
  nextcloud_themes:
```

---

## Step 6 — Start

```bash
docker compose up -d
```

First start takes 2–3 minutes — Nextcloud installs itself, creates the database schema, and configures Redis. Watch progress:

```bash
docker logs -f nc-app
# Wait for: "Nextcloud was successfully installed"
```

Then open: `https://localhost`
Accept the self-signed certificate warning and log in with your admin credentials.

---

## Step 7 — Post-Install Configuration (Important)

Run these after first login to apply best practices:

```bash
# Set background job mode to cron (not AJAX)
docker exec -u www-data nc-app php occ background:cron

# Enable Redis file locking
docker exec -u www-data nc-app php occ config:system:set \
  redis host --value redis

docker exec -u www-data nc-app php occ config:system:set \
  memcache.local --value '\OC\Memcache\Redis'

docker exec -u www-data nc-app php occ config:system:set \
  memcache.locking --value '\OC\Memcache\Redis'

# Set default phone region (required to pass security check)
docker exec -u www-data nc-app php occ config:system:set \
  default_phone_region --value IR

# Fix any missing indices in the database
docker exec -u www-data nc-app php occ db:add-missing-indices

# Convert columns to BigInt (recommended for large installs)
docker exec -u www-data nc-app php occ db:convert-filecache-bigint --no-interaction
```

---

## Step 8 — Verify the Setup

```bash
# Run the built-in security and setup check
docker exec -u www-data nc-app php occ setupchecks

# Check overall system status
docker exec -u www-data nc-app php occ status

# Confirm Redis is working
docker exec -u www-data nc-app php occ config:system:get memcache.locking

# Check background jobs are running
docker exec -u www-data nc-app php occ background:job:list
```

Expected output from `occ status`:
```
- installed: true
- version: 28.x.x
- versionstring: Nextcloud Hub x
- edition:
```

---

## Step 9 — Test

```bash
# HTTP redirects to HTTPS
curl -I http://localhost/
# Expected: 301 → https://localhost/

# HTTPS home page loads
curl -kI https://localhost/
# Expected: 200 OK

# CalDAV redirect works
curl -kI https://localhost/.well-known/caldav
# Expected: 301 → /remote.php/dav

# CardDAV redirect works
curl -kI https://localhost/.well-known/carddav
# Expected: 301 → /remote.php/dav
```

---

## Step 10 — Maintenance Commands

```bash
# Enable maintenance mode (before updates/backups)
docker exec -u www-data nc-app php occ maintenance:mode --on

# Disable maintenance mode
docker exec -u www-data nc-app php occ maintenance:mode --off

# Update all apps
docker exec -u www-data nc-app php occ app:update --all

# Scan user files (if files were added outside Nextcloud)
docker exec -u www-data nc-app php occ files:scan --all

# Clear caches
docker exec -u www-data nc-app php occ files:cleanup
```

---

## Step 11 — Backup

```bash
# 1. Enable maintenance mode
docker exec -u www-data nc-app php occ maintenance:mode --on

# 2. Backup database
docker exec nc-postgres pg_dump -U nextclouduser nextclouddb \
  > backup_$(date +%Y%m%d).sql

# 3. Backup Nextcloud volumes
docker run --rm \
  -v nextcloud_data:/data \
  -v $(pwd):/backup \
  docker.arvancloud.ir/alpine \
  tar czf /backup/nextcloud_data_$(date +%Y%m%d).tar.gz /data

# 4. Disable maintenance mode
docker exec -u www-data nc-app php occ maintenance:mode --off
```

---

## Step 12 — Update Nextcloud

```bash
# 1. Enable maintenance mode
docker exec -u www-data nc-app php occ maintenance:mode --on

# 2. Pull new image
docker compose pull nextcloud cron

# 3. Recreate containers
docker compose up -d --no-deps nextcloud cron

# 4. Run upgrade
docker exec -u www-data nc-app php occ upgrade

# 5. Disable maintenance mode
docker exec -u www-data nc-app php occ maintenance:mode --off
```

---

## Troubleshooting

### Nextcloud shows "Trusted domain" error
```bash
docker exec -u www-data nc-app php occ config:system:set \
  trusted_domains 0 --value localhost

# Add more domains if needed (1, 2, 3...)
docker exec -u www-data nc-app php occ config:system:set \
  trusted_domains 1 --value yourdomain.com
```

### Redis connection error
```bash
# Check Redis is reachable from Nextcloud container
docker exec nc-app ping -c 1 redis

# Check Redis password is correct
docker exec nc-redis redis-cli -a $REDIS_PASSWORD ping
```

### Large file uploads fail
Increase both values in `.env`:
```env
PHP_UPLOAD_LIMIT=20G
```
And in `nginx.conf`:
```nginx
client_max_body_size 20G;
```
Then restart:
```bash
docker compose restart nextcloud nginx
```

### Check logs
```bash
docker logs nc-app       # Nextcloud / PHP-FPM
docker logs nc-nginx     # Nginx access + errors
docker logs nc-postgres  # Database
docker logs nc-cron      # Background jobs
```

---

## Security Checklist

- [ ] Changed all default passwords in `.env`
- [ ] SSL certificate is valid (not expired)
- [ ] `X-Frame-Options`, `HSTS`, and other security headers are set (nginx.conf above includes them)
- [ ] Admin account has a strong password
- [ ] Two-factor authentication enabled for admin
- [ ] `occ setupchecks` reports no errors
- [ ] Cron container is running (not AJAX mode)
- [ ] Redis password is set
- [ ] Postgres is not exposed on host ports
- [ ] Nextcloud data volume is not bind-mounted to a world-readable path
- [ ] Regular backups are scheduled

---

## Volume Summary

| Volume | What's inside | Critical? |
|--------|--------------|-----------|
| `pgdata` | All database tables and user data | Yes — back up |
| `nextcloud_data` | User files, logs, Nextcloud core | Yes — back up |
| `nextcloud_config` | `config.php` — all settings | Yes — back up |
| `nextcloud_apps` | Installed apps | No — reinstallable |
| `nextcloud_themes` | Custom themes | No — reinstallable |
| `redisdata` | Cache only | No — auto-rebuilt |

---

## Clean Up

```bash
docker compose down          # stop containers
docker compose down -v       # stop + delete all volumes (ALL DATA LOST)
```
