# Prometheus Node Exporter (v1.8.2) - ARM64 Installation Guide

This guide provides step-by-step instructions to install and configure **Prometheus Node Exporter v1.8.2** on a Linux ARM64 system.

---

## 📥 Download and Install Node Exporter

1. **Download the latest release for ARM64:**
   ```bash
   wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-arm64.tar.gz
   ```

2. **Extract the tarball:**
   ```bash
   tar -xvzf node_exporter-1.8.2.linux-arm64.tar.gz
   cd node_exporter-1.8.2.linux-arm64
   ```

3. **Move the binary to `/usr/local/bin`:**
   ```bash
   sudo mv node_exporter /usr/local/bin/
   ```

4. **Create a dedicated user for security:**
   ```bash
   sudo useradd --no-create-home --shell /bin/false node_exporter
   ```

5. **Set the correct permissions:**
   ```bash
   sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
   ```

---

## ⚙️ Configure Node Exporter as a Systemd Service

1. **Create a new systemd service file:**
   ```bash
   sudo nano /etc/systemd/system/node_exporter.service
   ```

2. **Add the following configuration:**
   ```ini
   [Unit]
   Description=Prometheus Node Exporter
   Wants=network-online.target
   After=network-online.target

   [Service]
   User=node_exporter
   Group=node_exporter
   Type=simple
   ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100

   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

3. **Reload systemd and start the service:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable node_exporter
   sudo systemctl start node_exporter
   ```

4. **Verify the service is running:**
   ```bash
   sudo systemctl status node_exporter
   ```

   You should see output similar to:

   ```
   ● node_exporter.service - Prometheus Node Exporter
      Loaded: loaded (/etc/systemd/system/node_exporter.service; enabled; vendor preset: enabled)
      Active: active (running) since ...
   ```

---

## 🔥 Allow Node Exporter in Firewall (Optional)

If a firewall is enabled, allow Node Exporter traffic:

```bash
sudo ufw allow 9100/tcp
```

---

## 🔍 Verify Node Exporter is Running

You can test if Node Exporter is running by opening a browser and navigating to:

```
http://YOUR_SERVER_IP:9100/metrics
```

Or using `curl`:

```bash
curl http://localhost:9100/metrics
```

---

## 📡 Configure Prometheus to Scrape Node Exporter

1. **Edit Prometheus configuration file:**
   ```bash
   sudo nano /etc/prometheus/prometheus.yml
   ```

2. **Add the following under `scrape_configs`:**
   ```yaml
   scrape_configs:
     - job_name: 'node_exporter'
       static_configs:
         - targets: ['YOUR_SERVER_IP:9100']
   ```

3. **Restart Prometheus to apply changes:**
   ```bash
   sudo systemctl restart prometheus
   ```

4. **Check if Node Exporter is listed in Prometheus Targets:**
   ```
   http://YOUR_SERVER_IP:9090/targets
   ```

---

## ✅ **Node Exporter is Successfully Installed!**

Now **Prometheus is collecting system metrics from Node Exporter** 🎯. If you face any issues, check logs using:

```bash
journalctl -u node_exporter --no-pager --lines=50
```

---

## 📌 **Useful Links**
- 📖 [Prometheus Official Documentation](https://prometheus.io/docs/)
- 🛠️ [Node Exporter GitHub Repository](https://github.com/prometheus/node_exporter)
- 🔄 [Download Latest Node Exporter Releases](https://github.com/prometheus/node_exporter/releases)

---

### 🚀 **Happy Monitoring with Prometheus!**
