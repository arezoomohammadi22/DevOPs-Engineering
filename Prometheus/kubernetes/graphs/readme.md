# 📊 Kubernetes Monitoring with Grafana & Prometheus

This guide explains how to **install Grafana**, import Kubernetes monitoring dashboards, and visualize **kube-state-metrics**, **cAdvisor**, and **Node Exporter** data.

---

## 🚀 1. Install Grafana on Kubernetes
Run the following command to install **Grafana** using Helm:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install grafana grafana/grafana --namespace monitoring
```

### **Access Grafana Web UI**
Run:
```bash
kubectl port-forward svc/grafana 3000:80 -n monitoring
```
Then open in a browser:
```
http://localhost:3000
```
Default credentials:
- **Username:** `admin`
- **Password:** `admin`

---

## 📡 2. Add Prometheus as a Data Source
1. Open **Grafana UI** (`http://localhost:3000`).
2. Click on **"Configuration" → "Data Sources"**.
3. Click **"Add data source"**.
4. Select **"Prometheus"**.
5. Set **URL** to:
   ```
   http://prometheus.monitoring.svc.cluster.local:9090
   ```
6. Click **"Save & Test"**.

---

## 📌 3. Import Kubernetes Dashboards in Grafana
Grafana has pre-built dashboards for **monitoring Kubernetes**.

### **🔹 Dashboard 1: Kube-State-Metrics v2 (ID: 21742)**
- Focuses on **pods, nodes, deployments, and namespaces**.
- Requires **kube-state-metrics**.

#### **Download & Import Manually**
Run:
```bash
wget -O kube-state-metrics-v2.json https://grafana.com/api/dashboards/21742/revisions/latest/download
```
Then **import it into Grafana**:
1. Open **Grafana → Dashboards → Import**.
2. Click **"Upload JSON file"**.
3. Select **`kube-state-metrics-v2.json`**.
4. Click **"Load"** and choose **Prometheus** as the data source.

---

### **🔹 Dashboard 2: Kubernetes Pod Metrics (ID: 747)**
- Focuses on **Pod CPU, memory, and network usage**.
- Requires **kube-state-metrics**.

#### **Download & Import Manually**
Run:
```bash
wget -O kubernetes-pod-metrics.json https://grafana.com/api/dashboards/747/revisions/latest/download
```
Then **import it into Grafana**.

---

### **🔹 Dashboard 3: Node Exporter Full (ID: 1860)**
- Provides **CPU, memory, disk, and network metrics**.
- Requires **Node Exporter**.

#### **Download & Import Manually**
Run:
```bash
wget -O node-exporter-dashboard.json https://grafana.com/api/dashboards/1860/revisions/latest/download
```
Then **import it into Grafana**.

---

### **🔹 Dashboard 4: Kubernetes Cluster Monitoring (ID: 315)**
- A **full Kubernetes monitoring dashboard** that combines multiple metrics.
- Requires **kube-state-metrics, cAdvisor, and Node Exporter**.

#### **Download & Import Manually**
Run:
```bash
wget -O kubernetes-cluster-monitoring.json https://grafana.com/api/dashboards/315/revisions/latest/download
```
Then **import it into Grafana**.

---

## 🔍 4. Verify Kubernetes Metrics in Prometheus
If dashboards show **"No Data"**, check Prometheus by running:

### **Check if kube-state-metrics is being scraped**
Run:
```bash
kubectl get svc -n monitoring kube-state-metrics
```
Find the **ClusterIP** and update `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'kube-state-metrics'
    static_configs:
      - targets: ['kube-state-metrics.monitoring.svc.cluster.local:8080']
```

Restart Prometheus:
```bash
kubectl rollout restart deployment prometheus-server -n monitoring
```

Then test queries in **Prometheus UI (`http://YOUR_PROMETHEUS_IP:9090`)**:

```promql
kube_pod_status_ready
kube_node_status_condition{condition="Ready"}
kube_deployment_spec_replicas
```

---

## 📊 5. Using Grafana to Create Custom Kubernetes Graphs
To **manually create custom graphs**, follow these steps:

### **🔹 Step 1: Create a New Dashboard**
1. Click **"Dashboards" → "New Dashboard"**.
2. Click **"Add a new panel"**.

### **🔹 Step 2: Add PromQL Queries**
Use the following **PromQL queries** for different Kubernetes metrics:

| **Metric** | **Query (PromQL)** | **Description** |
|------------|------------------|----------------|
| **Pod Status** | `kube_pod_status_ready` | Shows if pods are running |
| **CPU Usage** | `rate(container_cpu_usage_seconds_total[5m])` | CPU usage per pod |
| **Memory Usage** | `container_memory_usage_bytes` | Memory usage per pod |
| **Node CPU Usage** | `rate(node_cpu_seconds_total[5m])` | CPU usage per node |
| **Node Memory Available** | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` | Available memory (%) |

### **🔹 Step 3: Save & View Graph**
1. Click **"Apply"**.
2. Click **"Save"**.
3. View the real-time **Kubernetes cluster metrics**.

---

## **✅ Summary: Full Kubernetes Monitoring Setup**
| **Component** | **Purpose** | **Installation Command** |
|--------------|------------|-------------------------|
| **Grafana** | Visualizes Kubernetes metrics | `helm install grafana grafana/grafana` |
| **kube-state-metrics** | Monitors pod & node states | `helm install kube-state-metrics bitnami/kube-state-metrics` |
| **cAdvisor** | Monitors container CPU & memory | `kubectl apply -f cadvisor-daemonset.yaml` |
| **Node Exporter** | Monitors node-level system metrics | `kubectl apply -f node-exporter-daemonset.yaml` |
| **Prometheus** | Collects Kubernetes metrics | `helm install prometheus prometheus-community/kube-prometheus-stack` |

🚀 **Now your Kubernetes cluster is fully monitored with Grafana!** 🎯

Let me know if you need more help!
