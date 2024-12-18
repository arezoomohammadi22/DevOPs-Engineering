# Configuring Multi-Line Logs Example

## Overview
This example shows how to use a Kubernetes ConfigMap to store multi-line configuration data, such as log configuration files. The ConfigMap is then mounted as a file into the application container.

## Files
1. `configmap.yaml`: Defines the ConfigMap with a log configuration file.
2. `deployment.yaml`: Mounts the ConfigMap as a file inside the container.

## Deployment Steps
1. Apply the ConfigMap:
    ```sh
    kubectl apply -f configmap.yaml
    ```

2. Deploy the application:
    ```sh
    kubectl apply -f deployment.yaml
    ```

3. Verify the deployment:
    ```sh
    kubectl get pods
    ```

4. Check the log configuration file inside the container:
    ```sh
    kubectl exec -it <pod-name> -- cat /etc/log-config.yml
    ```

## Key Points
- Multi-line configuration files are commonly stored in ConfigMaps.
- Ensure the `subPath` field is used if only specific keys need to be mounted as files.
