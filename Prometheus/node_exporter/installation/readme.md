# 📊 How to Create Graphs in Prometheus UI

This guide explains how to create and visualize **Prometheus metrics** using the built-in **Prometheus UI**.

---

## 🚀 1. Open Prometheus Web UI
1. Open your browser and go to:
   ```
   http://YOUR_PROMETHEUS_IP:9090
   ```
2. Click on the **"Graph"** tab.

---

## 📈 2. Enter a PromQL Query
1. In the **"Expression"** box, type a **PromQL query**.
2. Example: To see CPU usage per core:
   ```
   node_cpu_seconds_total
   ```
3. Click **"Execute"** to fetch data.

---

## 🎨 3. Switch to Graph Mode
1. Click on the **"Graph"** button (next to "Table").
2. You will now see a **time-series graph**.

---

## ⚙️ 4. Customize Graph Display
- **Time Range**: Change the **"Range"** (default: 1 hour) to **5m, 15m, 1h, etc.**
- **Step Interval**: Set a different step (e.g., **10s, 1m**) for better resolution.
- **Hover Over Data Points**: Move the mouse over the graph to see values.

---

## 📊 5. Example PromQL Queries for Graphs

### **CPU Metrics**
| **Query** | **Description** |
|-----------|----------------|
| `rate(node_cpu_seconds_total[5m])` | CPU usage rate over 5 minutes |
| `100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | CPU utilization percentage |

### **Memory Metrics**
| **Query** | **Description** |
|-----------|----------------|
| `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` | Available memory percentage |
| `node_memory_MemFree_bytes` | Free memory in bytes |
| `node_memory_Buffers_bytes + node_memory_Cached_bytes` | Buffers + Cached memory |

### **Disk Metrics**
| **Query** | **Description** |
|-----------|----------------|
| `node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"} ` | Used disk space (bytes) |
| `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100` | Free disk space (%) |
| `rate(node_disk_read_bytes_total[5m])` | Disk read rate (bytes/sec) |
| `rate(node_disk_written_bytes_total[5m])` | Disk write rate (bytes/sec) |

### **Network Metrics**
| **Query** | **Description** |
|-----------|----------------|
| `rate(node_network_receive_bytes_total[5m])` | Incoming network traffic rate |
| `rate(node_network_transmit_bytes_total[5m])` | Outgoing network traffic rate |
| `rate(node_network_receive_packets_total[5m])` | Incoming packets per second |
| `rate(node_network_transmit_packets_total[5m])` | Outgoing packets per second |

### **Load & Uptime Metrics**
| **Query** | **Description** |
|-----------|----------------|
| `node_load1` | 1-minute load average |
| `node_load5` | 5-minute load average |
| `node_load15` | 15-minute load average |
| `node_boot_time_seconds` | System boot time (seconds since Unix epoch) |
| `time() - node_boot_time_seconds` | System uptime in seconds |

### **Process & System Monitoring**
| **Query** | **Description** |
|-----------|----------------|
| `node_processes_running` | Number of running processes |
| `node_processes_blocked` | Number of blocked processes |
| `node_context_switches_total` | Total number of context switches |

### **Temperature Sensors (For Hardware Monitoring)**
| **Query** | **Description** |
|-----------|----------------|
| `node_hwmon_temp_celsius` | CPU/GPU temperature (if available) |

Try different queries to explore your data.

---

## 📊 6. Use Grafana for Advanced Graphs (Optional)
For **better visualization**, use **Grafana**:
1. **Install Grafana** and connect **Prometheus** as a data source.
2. Create **custom dashboards** with **alerts and panel visualizations**.

---

## ✅ Done! Now You Can Create Graphs in Prometheus!

Let me know if you need more help! 🚀
