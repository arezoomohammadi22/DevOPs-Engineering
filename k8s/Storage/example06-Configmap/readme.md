# Application Configuration Example

## Overview
This example shows how to use a Kubernetes ConfigMap to store environment variables for an application. The ConfigMap is then referenced in a Deployment to set container environment variables.

## Files
1. `configmap.yaml`: Defines the ConfigMap with application settings like `APP_ENV` and `LOG_LEVEL`.
2. `deployment.yaml`: Uses the ConfigMap to set environment variables for the application container.

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

4. Check the environment variables inside the container:
    ```sh
    kubectl exec -it <pod-name> -- env
    ```

## Key Points
- ConfigMaps are ideal for non-sensitive data like environment variables.
- Avoid using ConfigMaps for credentials or sensitive data; use Secrets instead.
