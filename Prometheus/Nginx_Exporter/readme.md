# 📊 Monitoring Multiple Nginx Server Blocks with Prometheus

This guide explains how to monitor **multiple Nginx virtual hosts (server blocks)** using **Prometheus and Nginx Exporter**.

---

## 🚀 1. Enable Nginx Status Page Per Server Block

To monitor individual **server blocks**, configure each one to expose **stub_status**.

### **Edit Nginx Configuration**
Run:
```bash
sudo nano /etc/nginx/nginx.conf
```

### **Add `stub_status` to Each Server Block**
```nginx
server {
    listen 80;
    server_name example1.com;

    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}

server {
    listen 80;
    server_name example2.com;

    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
```

### **Restart Nginx**
```bash
sudo systemctl restart nginx
```

### **Verify Status Pages**
```bash
curl http://example1.com/nginx_status
curl http://example2.com/nginx_status
```
Each domain should return **separate metrics**.

---

## 📡 2. Run Nginx Exporter for Each Server Block

Nginx Exporter translates `nginx_status` into **Prometheus metrics**. You need **separate exporters** for each virtual host.

### **Using Docker**:
```bash
docker run -d   --name=nginx_exporter_example1   -p 9113:9113   nginx/nginx-prometheus-exporter:latest   -nginx.scrape-uri http://example1.com/nginx_status

docker run -d   --name=nginx_exporter_example2   -p 9114:9113   nginx/nginx-prometheus-exporter:latest   -nginx.scrape-uri http://example2.com/nginx_status
```

### **If Running Without Docker**:
1. **Download & Install Nginx Exporter**
   ```bash
   wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/latest/download/nginx-prometheus-exporter-linux-amd64.tar.gz
   tar -xvzf nginx-prometheus-exporter-linux-amd64.tar.gz
   sudo mv nginx-prometheus-exporter /usr/local/bin/
   ```

2. **Run Separate Instances for Each Server Block**
   ```bash
   /usr/local/bin/nginx-prometheus-exporter -nginx.scrape-uri http://example1.com/nginx_status -web.listen-address=:9113 &
   /usr/local/bin/nginx-prometheus-exporter -nginx.scrape-uri http://example2.com/nginx_status -web.listen-address=:9114 &
   ```

---

## ⚙️ 3. Configure Prometheus to Scrape Nginx Metrics

Now, configure **Prometheus** to scrape the exporters, **not** `nginx_status` directly.

### **Edit Prometheus Configuration**
```bash
sudo nano /etc/prometheus/prometheus.yml
```

### **Add Scrape Configs for Each Nginx Server Block**
```yaml
scrape_configs:
  - job_name: 'nginx_example1'
    static_configs:
      - targets: ['localhost:9113']  # Scraping example1.com

  - job_name: 'nginx_example2'
    static_configs:
      - targets: ['localhost:9114']  # Scraping example2.com
```

### **Restart Prometheus**
```bash
sudo systemctl restart prometheus
```

---

## 🔍 4. Verify Monitoring in Prometheus

### **Check Prometheus Targets**
Go to:
```
http://YOUR_PROMETHEUS_IP:9090/targets
```
You should see **two separate targets**:
- `nginx_example1` (example1.com)
- `nginx_example2` (example2.com)

### **Manually Test Metrics**
Check if exporters are providing metrics:
```
http://localhost:9113/metrics  # Metrics for example1.com
http://localhost:9114/metrics  # Metrics for example2.com
```

---

## 📊 5. Useful PromQL Queries for Nginx Monitoring

| **Query** | **Description** |
|-----------|----------------|
| `nginx_connections_active` | Number of active connections |
| `nginx_connections_accepted` | Total accepted connections |
| `nginx_connections_handled` | Total handled connections |
| `rate(nginx_http_requests_total[5m])` | Requests per second |
| `nginx_up` | 1 if Nginx is up, 0 if down |

---

## 📊 6. Visualizing Nginx Metrics in Grafana (Optional)
For **better visualization**, use **Grafana**:
1. Install **Grafana** and add **Prometheus** as a data source.
2. Import **Nginx Dashboard ID `9614`** from Grafana.

---

## ✅ Done! Now You Can Monitor Each Nginx Server Block Separately!
Let me know if you need more help! 🚀
