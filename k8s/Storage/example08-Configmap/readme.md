# Command-Line Arguments Example

## Overview
This example shows how to use a Kubernetes ConfigMap to provide command-line arguments to an application. The ConfigMap contains key-value pairs that are referenced in the Deployment to set container arguments.

## Files
1. `configmap.yaml`: Defines the ConfigMap with application arguments.
2. `deployment.yaml`: References the ConfigMap to set container arguments.

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

4. Check the container arguments:
    ```sh
    kubectl describe pod <pod-name>
    ```

## Key Points
- Use ConfigMaps to manage application arguments dynamically.
- Changes to ConfigMaps are not automatically reflected in running pods; recreate pods to apply updates.
