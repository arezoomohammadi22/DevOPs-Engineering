
# Project: Dependent Systemd Services Example

This project demonstrates how to create two dependent systemd services where:
1. **Service 1** is a long-running task, such as a database or background process.
2. **Service 2** is dependent on **Service 1**, meaning **Service 2** starts only after **Service 1** is up and running.

## Project Structure

```
.
├── service1.sh
├── service2.sh
├── service1.service
├── service2.service
└── README.md
```

## Prerequisites

- A Linux-based system with `systemd` support (most modern Linux distributions).
- `bash` and `systemd` should be available on the system.

## Files

### 1. `service1.sh`
This script simulates a long-running task, continuously printing the current time every second.

```bash
#!/bin/bash

# Running a long-running task
while true; do
  echo $(date)
  sleep 1
done
```

### 2. `service2.sh`
This script simulates another service that runs only after `service1.sh` is up and running.

```bash
#!/bin/bash

# Simulating a dependent task
while true; do
  echo "Service 2 is running after Service 1..."
  sleep 1
done
```

### 3. `service1.service`
This is the `systemd` service unit file for **Service 1**, which runs the `service1.sh` script.

```ini
[Unit]
Description=Service 1 - Running Long-Running Task
After=network.target

[Service]
ExecStart=/usr/local/bin/service1.sh
Restart=always
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 4. `service2.service`
This is the `systemd` service unit file for **Service 2**, which runs the `service2.sh` script and depends on `service1.service`.

```ini
[Unit]
Description=Service 2 - Dependent on Service 1
After=service1.service
Requires=service1.service

[Service]
ExecStart=/usr/local/bin/service2.sh
Restart=always
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

## Installation

1. Copy the scripts (`service1.sh` and `service2.sh`) to the `/usr/local/bin/` directory:

    ```bash
    sudo cp service1.sh /usr/local/bin/
    sudo cp service2.sh /usr/local/bin/
    ```

2. Make sure both scripts are executable:

    ```bash
    sudo chmod +x /usr/local/bin/service1.sh
    sudo chmod +x /usr/local/bin/service2.sh
    ```

3. Copy the `systemd` service unit files (`service1.service` and `service2.service`) to the `/etc/systemd/system/` directory:

    ```bash
    sudo cp service1.service /etc/systemd/system/
    sudo cp service2.service /etc/systemd/system/
    ```

4. Reload the `systemd` configuration:

    ```bash
    sudo systemctl daemon-reload
    ```

5. Enable and start the services:

    ```bash
    sudo systemctl enable service1.service
    sudo systemctl enable service2.service
    sudo systemctl start service1.service
    sudo systemctl start service2.service
    ```

## Checking the status

You can check the status of the services using the following commands:

```bash
sudo systemctl status service1.service
sudo systemctl status service2.service
```

To view the logs, you can use:

```bash
sudo journalctl -u service1.service -f
sudo journalctl -u service2.service -f
```

## Notes

- `Service 2` will only start once `Service 1` has successfully started. If `Service 1` fails to start, `Service 2` will not start.
- The services are configured to automatically restart if they fail (via `Restart=always`).
