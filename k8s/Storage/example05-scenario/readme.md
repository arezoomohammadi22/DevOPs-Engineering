# Kubernetes Web Application

## Overview
This repository contains Kubernetes manifests for deploying a web application along with a MySQL database. The web application supports simple REST APIs for inserting and fetching data from the database.

## Components
1. **Web Application**:
   - A Python Flask app with endpoints to interact with the MySQL database.
2. **MySQL Database**:
   - Deployed as a StatefulSet with persistent storage for data durability.
3. **MySQL Init Job**:
   - A Kubernetes Job that initializes the database by creating necessary tables.
4. **WebApp ConfigMap**:
   - Stores non-sensitive application configuration parameters.

## Features
- Environment variables securely managed using Kubernetes Secrets for sensitive data.
- Configuration parameters managed using ConfigMaps for flexibility.
- Health checks with readiness and liveness probes for better reliability.
- Persistent storage for MySQL database to ensure data is retained.

---

## Deployment Instructions

### Prerequisites
- A Kubernetes cluster.
- `kubectl` CLI configured to interact with the cluster.
- A PersistentVolume provisioner for MySQL storage.

### Steps
1. Clone the repository:
    ```sh
    git clone <repository_url>
    cd <repository_directory>
    ```

2. Apply Kubernetes manifests in the following order:
    ```sh
    kubectl apply -f webapp-config.yaml
    kubectl apply -f webapp-secret.yaml
    kubectl apply -f mysql-deployment.yaml
    kubectl apply -f webapp-deployment.yaml
    kubectl apply -f webapp-service.yaml
    ```

3. Verify the resources:
    ```sh
    kubectl get all
    ```

4. Initialize the MySQL database:
    ```sh
    kubectl apply -f mysql-init-job.yaml
    ```
    Check the status of the job:
    ```sh
    kubectl get jobs
    ```
    Confirm the logs to ensure successful initialization:
    ```sh
    kubectl logs job/mysql-init-job
    ```

5. Obtain the external IP address of the web application:
    ```sh
    kubectl get svc webapp-service
    ```

---

## API Endpoints

### Base URL
The base URL is determined by the external IP obtained from the `webapp-service`. Replace `<EXTERNAL_IP>` in the following examples.

### Endpoints

1. **Insert Data**
    - **Method**: `POST`
    - **Endpoint**: `/api/data`
    - **Request Body**:
      ```json
      {
        "data": "your_data"
      }
      ```
    - **Example `curl` Command**:
      ```sh
      curl -X POST http://<EXTERNAL_IP>/api/data       -H "Content-Type: application/json"       -d '{"data": "sample_data"}'
      ```

2. **Fetch Data**
    - **Method**: `GET`
    - **Endpoint**: `/api/data`
    - **Example `curl` Command**:
      ```sh
      curl http://<EXTERNAL_IP>/api/data
      ```

---

## Notes
1. Replace `<EXTERNAL_IP>` in the above `curl` commands with the actual IP of your service.
2. Ensure the MySQL StatefulSet is running properly by checking the logs:
    ```sh
    kubectl logs -l app=mysql
    ```

## Troubleshooting
- If the web application fails to connect to MySQL, ensure the `webapp-secret`, `webapp-config`, and `mysql` StatefulSet are properly configured.
- Debug resource events and logs:
    ```sh
    kubectl describe pod <POD_NAME>
    kubectl logs <POD_NAME>
    ```


