# Zabbix Agent Installation Guide

This guide explains how to install and configure the Zabbix Agent on Ubuntu 20.04.

## Prerequisites
- A system running Ubuntu 20.04
- Root or sudo privileges

## Installation Steps

### 1. Become Root User
Start a new shell session with root privileges:

```sh
sudo -s
```

### 2. Install Zabbix Repository
Download and install the Zabbix repository package:

```sh
wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.2+ubuntu20.04_all.deb
```

Install the package:

```sh
dpkg -i zabbix-release_latest_7.2+ubuntu20.04_all.deb
```

Update package lists:

```sh
apt update
```

### 3. Install Zabbix Agent
Install the Zabbix agent package:

```sh
apt install zabbix-agent
```

### 4. Start and Enable Zabbix Agent
Start the Zabbix agent process and enable it to start at system boot:

```sh
systemctl restart zabbix-agent
systemctl enable zabbix-agent
```

## Verification
Check the status of the Zabbix agent to ensure it is running:

```sh
systemctl status zabbix-agent
```

If everything is set up correctly, the Zabbix agent should be running without errors.

## Configuration (Optional)
You may need to edit the Zabbix agent configuration file to specify the Zabbix server address:

```sh
nano /etc/zabbix/zabbix_agentd.conf
```

Find and modify the following lines:

```
Server=<ZABBIX_SERVER_IP>
ServerActive=<ZABBIX_SERVER_IP>
Hostname=<YOUR_HOSTNAME>
```

Save the file and restart the Zabbix agent:

```sh
systemctl restart zabbix-agent
```

## Conclusion
You have successfully installed and configured the Zabbix agent on your Ubuntu 20.04 system. Ensure that your firewall allows communication between the Zabbix agent and the Zabbix server.
