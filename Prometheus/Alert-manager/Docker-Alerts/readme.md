# Docker Host & Container Monitoring with Prometheus & Alertmanager

This repository contains **Prometheus alert rules** for monitoring a **Docker host and running containers** using **cAdvisor**.

## 📌 Features
- 🚀 **Monitor CPU & Memory usage** of containers
- 📺 **Detect container restarts & stopped containers**
- 💲 **Check for low disk space**
- 📱 **Monitor network traffic**
- 🐙 **Alert if Docker Daemon is down**
- 🛠️ **Ensure cAdvisor is running properly**

## 📂 Files
- `alert_rules.yml` → Contains alert rules for **Prometheus & Alertmanager**.
- `prometheus.yml` → Configuration for Prometheus to use Alertmanager.
- `docker-compose.yml` → Deploys **Prometheus, cAdvisor, Alertmanager, and Grafana**.

---

## 🚀 Getting Started

### **1️⃣ Setup `alert_rules.yml`**
Create a file named `alert_rules.yml` and add the following alert rules:

```yaml
groups:
  - name: docker_alerts
    rules:
      - alert: HighContainerCPUUsage
        expr: rate(container_cpu_usage_seconds_total{container_label_com_docker_compose_service!=""}[1m]) * 100 > 80
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on container {{ $labels.name }}"
          description: "Container {{ $labels.name }} is using more than 80% CPU for over 1 minute."

      - alert: HighContainerMemoryUsage
        expr: (container_memory_usage_bytes{container_label_com_docker_compose_service!=""} / container_spec_memory_limit_bytes) * 100 > 75
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on container {{ $labels.name }}"
          description: "Container {{ $labels.name }} is using more than 75% of its allocated memory."

      - alert: ContainerRestarted
        expr: increase(container_restart_count{container_label_com_docker_compose_service!=""}[10m]) > 5
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container restarted multiple times {{ $labels.name }}"
          description: "Container {{ $labels.name }} has restarted more than 5 times in the last 10 minutes."

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 20
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk usage has exceeded 80% on {{ $labels.instance }}."

      - alert: HighNetworkTraffic
        expr: rate(container_network_receive_bytes_total{container_label_com_docker_compose_service!=""}[1m]) > 100000000
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High network traffic on container {{ $labels.name }}"
          description: "Container {{ $labels.name }} is receiving more than 100MB/s of network traffic."

      - alert: DockerDaemonDown
        expr: absent(up{job="cadvisor"} == 1)
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Docker daemon is down on {{ $labels.instance }}"
          description: "The Docker daemon has been unavailable for the last 5 minutes."

      - alert: StoppedContainer
        expr: container_last_seen{container_label_com_docker_compose_service!=""} < time() - 300
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} is stopped"
          description: "Container {{ $labels.name }} has been stopped for more than 5 minutes."
```

---

### **2️⃣ Configure Prometheus to Use Alert Rules**
Edit `prometheus.yml` to include:

```yaml
rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - "alertmanager:9093"
```

---

### **3️⃣ Run Prometheus + Alertmanager + cAdvisor**
Use Docker Compose:

```sh
docker-compose up -d
```

---

### **4️⃣ Test Alerts**
Manually trigger an alert:

```sh
curl -XPOST http://localhost:9093/api/v1/alerts -d '[
  {
    "labels": {
      "alertname": "TestAlert",
      "instance": "localhost"
    },
    "annotations": {
      "summary": "Test alert triggered"
    },
    "startsAt": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
    "endsAt": "'$(date -u -d '10 minutes' +"%Y-%m-%dT%H:%M:%SZ")'"
  }
]'
```

---

## 📊 **Access Monitoring Dashboard**
- **Prometheus:** [http://localhost:9090](http://localhost:9090)
- **Alertmanager:** [http://localhost:9093](http://localhost:9093)
- **Grafana:** [http://localhost:3000](http://localhost:3000) (Default login: `admin/admin`)

---

## 🔥 **Alerts Included**
✅ **CPU Overload**  
✅ **Memory Overload**  
✅ **High Disk I/O**  
✅ **High Network Traffic**  
✅ **Docker Container Restarts**  
✅ **Low Disk Space**  
✅ **High Load Average**  
✅ **Stopped Containers**  
✅ **Docker Daemon Down**  
✅ **cAdvisor Down**  

---

## 🎯 **Next Steps**
- 🔹 **Customize alerts** to fit your requirements.
- 🔹 Integrate with **Grafana** for dashboards.
- 🔹 Use **Slack, Email, or Webhooks** for alert notifications.

---

## 🎉 **Done! Now your Docker containers and host are fully monitored!**

