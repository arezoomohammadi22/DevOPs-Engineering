# 📊 Monitoring Kubernetes with Prometheus & kube-state-metrics

This guide explains how to **install kube-state-metrics** using Helm and configure **Prometheus** to scrape Kubernetes metrics.

---

## 🚀 1. Install kube-state-metrics Using Helm

Run the following command to install **kube-state-metrics** in the `kube-state` namespace:

```bash
helm install kube-state-metrics bitnami/kube-state-metrics --namespace kube-state
```

### **Verify Installation**
Check the status of the deployment:
```bash
kubectl get pods -n kube-state
```

Expected output:
```
NAME                                  READY   STATUS    RESTARTS   AGE
kube-state-metrics-xxxxx              1/1     Running   0          5m
```

If the pod is not running, check logs:
```bash
kubectl logs -n kube-state deploy/kube-state-metrics
```

---

## 📡 2. Port-Forward kube-state-metrics (For Testing)

To test if kube-state-metrics is working, run:
```bash
kubectl port-forward -n kube-state svc/kube-state-metrics 9100:8080
```
Then, open your browser and go to:
```
http://127.0.0.1:9100/metrics
```
If everything is working, you should see Kubernetes metrics.

---

## ⚙️ 3. Configure Prometheus to Scrape kube-state-metrics

Edit your **Prometheus configuration file (`prometheus.yml`)**:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Add the following **scrape job** under `scrape_configs`:

```yaml
scrape_configs:
  - job_name: 'kube-state-metrics'
    metrics_path: /metrics
    static_configs:
      - targets: ['kube-state-metrics.kube-state.svc.cluster.local:8080']
```

### **If Prometheus is Running Outside Kubernetes**

Find the **ClusterIP** of kube-state-metrics:
```bash
kubectl get svc -n kube-state kube-state-metrics
```

Example output:
```
NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
kube-state-metrics    ClusterIP   10.96.120.56    <none>        8080/TCP    10m
```

Then, update Prometheus configuration to use this IP:
```yaml
scrape_configs:
  - job_name: 'kube-state-metrics'
    static_configs:
      - targets: ['10.96.120.56:8080']
```

Save the file and **restart Prometheus**:
```bash
sudo systemctl restart prometheus
```

---

## 🔍 4. Verify kube-state-metrics in Prometheus

Go to:
```
http://YOUR_PROMETHEUS_IP:9090/targets
```
You should see **kube-state-metrics** in the list of active targets.

Test some queries in the **Prometheus UI** (`http://YOUR_PROMETHEUS_IP:9090`):

```promql
kube_pod_status_ready
kube_deployment_spec_replicas
kube_node_status_condition{condition="Ready"}
```

If you see data, then **Prometheus is successfully scraping Kubernetes metrics!** 🚀

---

## 📊 5. Useful PromQL Queries for Kubernetes Monitoring

### **Pod & Deployment Metrics**
| **Query** | **Description** |
|-----------|----------------|
| `kube_pod_status_ready` | Check if pods are running |
| `kube_pod_container_status_restarts_total` | Number of pod restarts |
| `kube_deployment_spec_replicas` | Desired replicas per deployment |
| `kube_deployment_status_replicas_available` | Available replicas |

### **Node & Resource Metrics**
| **Query** | **Description** |
|-----------|----------------|
| `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` | Node memory usage % |
| `rate(container_cpu_usage_seconds_total[5m])` | CPU usage per pod |
| `kube_node_status_condition{condition="Ready"}` | Check if nodes are ready |

---

## 📊 6. Visualizing Kubernetes Metrics in Grafana

For **better visualization**, install **Grafana**:

```bash
helm install grafana prometheus-community/grafana
```

### **Steps in Grafana:**
1. **Add Prometheus as a data source.**
2. **Import Kubernetes Dashboard ID `315`.**
3. **View real-time Kubernetes metrics.**

---

## ✅ Done! Now Kubernetes Metrics Are in Prometheus! 🎯

