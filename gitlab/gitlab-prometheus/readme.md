# GitLab Omnibus Prometheus Setup Guide

This guide explains how to enable, verify, and access **Prometheus** that is bundled inside GitLab when installed via the Omnibus (`.sh`) package.

---

## 1. Check Running Services

```bash
sudo gitlab-ctl status | egrep 'prometheus|exporter'
sudo ss -lntp | egrep '9090|9100|9168|9187|9121'
```

- Prometheus listens on `localhost:9090` by default.  
- Common exporters:  
  - `gitlab-exporter:9168`  
  - `node-exporter:9100`  
  - `postgres-exporter:9187`  
  - `redis-exporter:9121`  

---

## 2. Enable Prometheus and Exporters

Edit `/etc/gitlab/gitlab.rb`:

```ruby
prometheus['enable'] = true

gitlab_exporter['enable'] = true
postgres_exporter['enable'] = true
redis_exporter['enable']  = true
node_exporter['enable']   = true
```

Apply changes:

```bash
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart prometheus
```

---

## 3. Expose the Web UI

Prometheus is bound to `127.0.0.1:9090` by default. To expose it externally:

```ruby
prometheus['listen_address'] = '0.0.0.0:9090'
```

Reconfigure again:

```bash
sudo gitlab-ctl reconfigure
```

Then browse:

```
http://<fqdn>:9090
```

### If behind reverse proxy (recommended):

```ruby
prometheus['listen_address'] = '127.0.0.1:9090'
prometheus['flags'] = {
  'web.external-url' => 'https://gitlab.example.com/prometheus/'
}
```

And add in NGINX config:

```ruby
nginx['custom_gitlab_server_config'] = <<-'NGINX'
location /prometheus/ {
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_pass http://127.0.0.1:9090;
}
NGINX
```

After reconfigure, access:

```
https://gitlab.example.com/prometheus/
```

> ⚠️ Always include the trailing slash `/prometheus/` in the URL.

---

## 4. Enable GitLab Metrics Endpoint

In GitLab admin UI:  
**Admin > Settings > Metrics and profiling > Enable GitLab Prometheus metrics endpoint**

This lets Prometheus scrape GitLab Rails & Sidekiq metrics.

---

## 5. Health Check

```bash
curl -sf http://127.0.0.1:9090/-/ready && echo "Prometheus is ready"
```

In the UI: go to **Status → Targets**.

---

## 6. Add Extra Scrape Targets

```ruby
prometheus['additional_scrape_configs'] = [
  {
    'job_name' => 'my-node',
    'static_configs' => [
      { 'targets' => ['10.0.0.5:9100'] }
    ]
  }
]
```

Reconfigure and check new jobs in **Status → Targets**.

---

## 7. Remote Write (Optional)

```ruby
prometheus['remote_write'] = [
  { 'url' => 'https://vm.example.com/api/v1/write' }
]
```

---

## Why You May See `/graph` 404 Errors

When reverse proxying Prometheus on a sub-path, set:

```ruby
prometheus['flags'] = {
  'web.external-url' => 'https://gitlab.example.com/prometheus/'
}
```

This ensures redirects go to `/prometheus/graph` instead of `/graph`.

---

## References

- [GitLab Prometheus Integration Docs](https://docs.gitlab.com/omnibus/settings/prometheus.html)
- [Prometheus Command-Line Flags](https://prometheus.io/docs/prometheus/latest/command-line/)
