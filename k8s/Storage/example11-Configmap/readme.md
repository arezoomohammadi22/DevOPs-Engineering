# General Key-Value Configuration

## Overview
This example demonstrates using a ConfigMap to store database-related configuration data as key-value pairs. The ConfigMap is consumed by a Pod as environment variables.

## Files
1. `example-configmap.yaml`: Defines the ConfigMap with configuration data.
2. `pod-env-var.yaml`: Deploys a Pod that uses the ConfigMap as environment variables.

## Deployment Steps
1. Create the ConfigMap:
    ```sh
    kubectl apply -f example-configmap.yaml
    ```

2. Create the Pod:
    ```sh
    kubectl apply -f pod-env-var.yaml
    ```

3. Verify the environment variables:
    ```sh
    kubectl exec -it pod-env-var -- env
    ```

## Key Points
- ConfigMaps allow dynamic injection of environment variables into containers.
- Changes to ConfigMaps do not automatically update running pods.
