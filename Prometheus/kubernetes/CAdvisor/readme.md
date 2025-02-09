# 📊 Installing cAdvisor on Kubernetes (containerd Support)

This guide explains how to install **cAdvisor** as a DaemonSet in Kubernetes for monitoring **containerd**, expose it via a **ClusterIP service**, and configure **Prometheus** to scrape its metrics.

---

## **🚀 1. Deploy cAdvisor on Kubernetes (Compatible with containerd)**
Create a file **`cadvisor-daemonset-containerd.yaml`**:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: monitoring
  labels:
    app: cadvisor
spec:
  selector:
    matchLabels:
      name: cadvisor
  template:
    metadata:
      labels:
        name: cadvisor
    spec:
      containers:
        - name: cadvisor
          image: gcr.io/cadvisor/cadvisor:v0.47.2
          ports:
            - containerPort: 8080
              hostPort: 8080
              protocol: TCP
          args:
            - "--containerd=/run/containerd/containerd.sock"
            - "--storage_driver=memory"
          securityContext:
            privileged: true  # Required for accessing system resources
          volumeMounts:
            - name: containerd
              mountPath: /run/containerd/containerd.sock
              readOnly: true
            - name: sys
              mountPath: /sys
              readOnly: true
            - name: kubelet
              mountPath: /var/lib/kubelet
              readOnly: true
            - name: rootfs
              mountPath: /rootfs
              readOnly: true
            - name: disk
              mountPath: /dev/disk
              readOnly: true
            - name: kmsg  # Required for OOM event detection
              mountPath: /dev/kmsg
              readOnly: true
      volumes:
        - name: containerd
          hostPath:
            path: /run/containerd/containerd.sock
        - name: sys
          hostPath:
            path: /sys
        - name: kubelet
          hostPath:
            path: /var/lib/kubelet
        - name: rootfs
          hostPath:
            path: /
        - name: disk
          hostPath:
            path: /dev/disk
        - name: kmsg
          hostPath:
            path: /dev/kmsg
```

### **🛠 Step 1: Apply the DaemonSet**
```bash
kubectl apply -f cadvisor-daemonset-containerd.yaml
```

### **🛠 Step 2: Verify cAdvisor is Running**
```bash
kubectl get pods -n monitoring
```
Expected output:
```
NAME                READY   STATUS    RESTARTS   AGE
cadvisor-xxxxx      1/1     Running   0          5m
```

---

## **📡 2. Expose cAdvisor as a ClusterIP Service**
To allow Prometheus to scrape metrics, create a **ClusterIP service** for cAdvisor.

Create a file **`cadvisor-service.yaml`**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: cadvisor
  namespace: monitoring
spec:
  selector:
    name: cadvisor
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
  type: ClusterIP
```

### **🛠 Step 1: Apply the Service**
```bash
kubectl apply -f cadvisor-service.yaml
```

### **🛠 Step 2: Verify the Service**
```bash
kubectl get svc -n monitoring
```
Expected output:
```
NAME       TYPE        CLUSTER-IP      PORT(S)   AGE
cadvisor   ClusterIP   10.96.20.200    8080/TCP  2m
```

Now, **cAdvisor is running and exposed inside the cluster!**

---

## **📌 3. Configure Prometheus to Scrape cAdvisor Metrics**
Edit **Prometheus configuration (`prometheus.yml`)**:

```yaml
scrape_configs:
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor.monitoring.svc.cluster.local:8080']
```

### **🛠 Step 1: Restart Prometheus**
```bash
kubectl rollout restart deployment prometheus-server -n monitoring
```

### **🛠 Step 2: Verify cAdvisor Metrics in Prometheus**
Open **Prometheus UI (`http://YOUR_PROMETHEUS_IP:9090`)** and run:

```promql
rate(container_cpu_usage_seconds_total[5m])
container_memory_usage_bytes
```

If data appears, **Prometheus is scraping cAdvisor successfully!** ✅

---

## **📊 4. View cAdvisor Metrics in Grafana**
Import **Grafana Dashboard ID 893** for **cAdvisor Monitoring**.

### **🛠 Steps to Import Grafana Dashboard**
1. **Go to Grafana → Dashboards → Import**
2. **Enter Dashboard ID: `893`**
3. **Select Prometheus as the data source**
4. Click **"Import"**.

🚀 **Now you have full container monitoring with cAdvisor in Grafana!** 🎯

---

## **✅ Summary: How to Install cAdvisor on Kubernetes with containerd**
| **Step** | **Action** |
|----------|-----------|
| **1. Deploy cAdvisor (containerd support)** | `kubectl apply -f cadvisor-daemonset-containerd.yaml` |
| **2. Expose cAdvisor Service** | `kubectl apply -f cadvisor-service.yaml` |
| **3. Verify cAdvisor** | `kubectl get pods -n monitoring` |
| **4. Configure Prometheus** | Add `cadvisor` job in `prometheus.yml` |
| **5. Restart Prometheus** | `kubectl rollout restart deployment prometheus-server -n monitoring` |
| **6. Check cAdvisor Metrics** | Run `container_cpu_usage_seconds_total` in Prometheus |
| **7. Import Grafana Dashboard** | Use **Grafana Dashboard ID `893`** |

🚀 **Now cAdvisor is fully integrated with Prometheus & Grafana for Kubernetes monitoring!** Let me know if you need any help! 🎯
