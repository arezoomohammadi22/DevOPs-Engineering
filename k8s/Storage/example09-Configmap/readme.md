# Storing Application Properties Example

## Overview
This example shows how to use a Kubernetes ConfigMap to store application properties in a key-value format, such as `application.properties`. The ConfigMap is then mounted into a container as a configuration file.

## Files
1. `configmap.yaml`: Defines the ConfigMap with application properties.
2. `deployment.yaml`: Mounts the ConfigMap as a configuration file inside the application container.

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

4. Test the configuration file inside the container:
    ```sh
    kubectl exec -it <pod-name> -- cat /config/application.properties
    ```

## Key Points
- ConfigMaps are useful for managing externalized application configuration.
- Ensure file paths inside the container match the application’s configuration expectations.
