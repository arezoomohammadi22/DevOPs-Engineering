# File-Based Configuration Example

## Overview
This example shows how to use a Kubernetes ConfigMap to mount configuration files into a container. The ConfigMap contains an `nginx.conf` file that configures an NGINX server.

## Files
1. `configmap.yaml`: Defines the ConfigMap with the `nginx.conf` content.
2. `deployment.yaml`: Mounts the ConfigMap as a file inside the NGINX container.

## Deployment Steps
1. Apply the ConfigMap:
    ```sh
    kubectl apply -f configmap.yaml
    ```

2. Deploy the NGINX application:
    ```sh
    kubectl apply -f deployment.yaml
    ```

3. Verify the deployment:
    ```sh
    kubectl get pods
    ```

4. Test the NGINX configuration:
    ```sh
    kubectl exec -it <nginx-pod> -- cat /etc/nginx/nginx.conf
    ```

## Key Points
- ConfigMaps can store configuration files, which can be mounted as volumes in containers.
- The `subPath` field allows mapping specific ConfigMap entries to file paths.
