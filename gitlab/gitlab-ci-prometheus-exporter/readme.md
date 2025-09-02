# GitLab CI Pipelines Exporter

This setup exports GitLab CI/CD pipeline and job metrics for Prometheus from a **single project**:  
`https://gitlab.sananetco.com/devops-scenarios/gitops-example01`

---

## 📦 Docker Setup

Run the GitLab CI Pipelines Exporter container:

```bash
docker run -d   --name gitlab-ci-pipelines-exporter   -p 8081:8080   -v "$(pwd)/gitlab-ci-pipelines-exporter.yml:/etc/gitlab-ci-pipelines-exporter.yml:ro"   -v /etc/hosts:/etc/hosts   mvisonneau/gitlab-ci-pipelines-exporter:latest-arm64   run --config /etc/gitlab-ci-pipelines-exporter.yml
```

> ℹ️ Metrics will be available at: `http://<host>:8081/metrics`

---

## ⚙️ Configuration

Below is the content of your `gitlab-ci-pipelines-exporter.yml`:

```yaml
gitlab:
  url: https://gitlab.sananetco.com
  token: token   # scopes: read_api (recommended: also add read_user, read_repository)

project_defaults:
  pull:
    pipeline:
      jobs:
        enabled: true

projects:
  - name: devops-scenarios/gitops-example01
    pull:
      pipeline:
        jobs:
          enabled: true

log:
  level: info

server:
  listen_address: 0.0.0.0:8080
```

---

## 🔐 Creating GitLab Access Token

To authenticate GitLab API access:

1. Visit: `https://gitlab.sananetco.com/-/profile/personal_access_tokens`
2. Create a new token with the following **scopes**:
   - `read_api` (minimum required)
   - `read_user`
   - `read_repository`
3. Copy the token and update your exporter config file under `gitlab.token`.

---

## 📊 Prometheus Integration

To scrape metrics from this exporter in Prometheus, add the following job to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'gitlab-ci-pipelines-exporter'
    static_configs:
      - targets: ['localhost:8081']  # or replace with exporter host IP
```

Then reload or restart Prometheus.

---

## 📈 Grafana Dashboards

You can use one or both of the following community dashboards:

1. **GitLab CI Pipelines Exporter**
   - 📊 Grafana Dashboard ID: [13328](https://grafana.com/grafana/dashboards/13328/)
   - Provides full CI job metrics including durations, status, etc.

2. **GitLab CI Pipelines (Alternative View)**
   - 📊 Grafana Dashboard ID: [10620](https://grafana.com/grafana/dashboards/10620-gitlab-ci-pipelines/)
   - Useful high-level view of pipeline activity and frequency

---

## ✅ Metrics Example

Visit your exporter in browser or curl:

```
http://localhost:8081/metrics
```

Example metrics:

```text
gcpe_gitlab_api_requests_count{endpoint="pipelines",status_code="200"} 10
gcpe_project_last_pipeline_status{project="devops-scenarios/gitops-example01",ref="main",status="success"} 1
gcpe_project_pipeline_duration_seconds{project="devops-scenarios/gitops-example01",ref="main"} 45
```

---

## 🛠 Tips & Troubleshooting

- Your GitLab project must have at least one **successful pipeline** to generate metrics.
- The GitLab token must be valid and not expired.
- Check logs with:

```bash
docker logs -f gitlab-ci-pipelines-exporter
```

---

## 🧾 References

- [GitLab CI Pipelines Exporter - GitHub](https://github.com/mvisonneau/gitlab-ci-pipelines-exporter)
- [Grafana Dashboard 13328](https://grafana.com/grafana/dashboards/13328/)
- [Grafana Dashboard 10620](https://grafana.com/grafana/dashboards/10620-gitlab-ci-pipelines/)
