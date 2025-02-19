# Monitoring Docker Host with Zabbix Agent 2

This guide explains how to monitor a Docker host using **Zabbix Agent 2** and the **Docker by Zabbix Agent 2** template.

## **1. Install Zabbix Agent 2 on Docker Host**
Zabbix Agent 2 must be installed on the Docker host to collect metrics.

### **Step 1: Install Zabbix Agent 2**
Run the following commands on the Docker host:

```sh
sudo apt update
sudo apt install zabbix-agent2 -y
```

### **Step 2: Configure Zabbix Agent 2**
Edit the Zabbix agent configuration file:

```sh
sudo nano /etc/zabbix/zabbix_agent2.conf
```

Modify these parameters:
```
Server=<ZABBIX_SERVER_IP>
ServerActive=<ZABBIX_SERVER_IP>
Hostname=<DOCKER_HOSTNAME>
```

Save the file and restart Zabbix Agent 2:

```sh
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2
```

---

## **2. Enable Docker Monitoring in Zabbix Agent 2**

### **Step 1: Add Zabbix User to Docker Group**
Zabbix Agent 2 requires access to the Docker socket to retrieve container metrics.

```sh
sudo usermod -aG docker zabbix
```

Restart Zabbix Agent 2:

```sh
sudo systemctl restart zabbix-agent2
```

### **Step 2: Enable Docker Plugin in Zabbix Agent 2**
Ensure the following line is present in the `zabbix_agent2.conf` file:

```sh
Plugins.Docker.Endpoint=unix:///var/run/docker.sock
```

Then restart the agent:

```sh
sudo systemctl restart zabbix-agent2
```

---

## **3. Configure Zabbix Web Interface**

### **Step 1: Import Zabbix Docker Template**
1. Log in to **Zabbix Web Interface**.
2. Navigate to **Configuration → Templates**.
3. Click **Import** and upload the **Docker by Zabbix agent 2** template.

### **Step 2: Link Template to Host**
1. Navigate to **Configuration → Hosts**.
2. Select your **Docker host**.
3. Click **Templates → Link new template**.
4. Search for **Docker by Zabbix agent 2** and link it.

### **Step 3: Update Macros**
1. Open your **Docker Host** in Zabbix.
2. Go to the **Macros** tab.
3. Update the following macro:
   - `{ZABBIX.DOCKER.SOCKET}` → `unix:///var/run/docker.sock`
4. Click **Update**.

---

## **4. Verify Docker Monitoring in Zabbix**
1. Navigate to **Monitoring → Latest Data**.
2. Select your **Docker Host**.
3. Check for Docker-related metrics such as:
   - Number of running containers
   - CPU & memory usage
   - Container uptime
   - Network traffic

---

## **5. Troubleshooting**

### **Check Agent Logs for Errors**
```sh
sudo journalctl -u zabbix-agent2 -f
```

### **Verify Docker Socket Permissions**
Ensure Zabbix Agent 2 can access the Docker socket:
```sh
ls -l /var/run/docker.sock
```
Expected output:
```
-rw-rw---- 1 root docker 0 Feb 19 12:00 /var/run/docker.sock
```
If needed, set permissions:
```sh
sudo chmod 666 /var/run/docker.sock
```

### **Test Docker Plugin**
Run the following command:
```sh
sudo -u zabbix zabbix_agent2 -t docker.info
```
Expected output:
```
docker.info                              [s|{"Containers":10,"Running":8,"Paused":0,"Stopped":2}]
```

---

## **6. Conclusion**
You have successfully set up **Zabbix Agent 2** to monitor your **Docker host** using the **Docker by Zabbix Agent 2** template. Your Zabbix server should now collect metrics from all running containers.

For additional customization, consider setting up alerts and dashboards in Zabbix!
