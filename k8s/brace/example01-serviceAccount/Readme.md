
# Kubernetes Role-Based Access Control (RBAC) Setup

This guide explains how to set up RBAC in Kubernetes using a ServiceAccount with the necessary permissions, and how to generate a kubeconfig file for accessing the cluster using this ServiceAccount.

---

## Prerequisites

1. A running Kubernetes cluster.
2. Access to `kubectl` configured to interact with your cluster.

---

## Files Description

1. **Role**: Defines the permissions to read pods in the `default` namespace.
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     namespace: default
     name: pod-reader
   rules:
   - apiGroups: [""]
     resources: ["pods"]
     verbs: ["get", "watch", "list"]
   ```

2. **RoleBinding**: Binds the `pod-reader` Role to the ServiceAccount.
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: RoleBinding
   metadata:
     name: read-pods
     namespace: default
   subjects:
   - kind: ServiceAccount
     name: sa-name
     namespace: default
   roleRef:
     kind: Role
     name: pod-reader
     apiGroup: rbac.authorization.k8s.io
   ```

3. **ServiceAccount**: Creates the ServiceAccount named `sa-name`.
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: sa-name
     namespace: default
   secrets:
   - name: secret-sa-sample
   ```

4. **Secret**: Token Secret for the ServiceAccount.
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: secret-sa-sample
     annotations:
       kubernetes.io/service-account.name: "sa-name"
   type: kubernetes.io/service-account-token
   ```

5. **Kubeconfig Template**: Config file for accessing the Kubernetes cluster using the ServiceAccount.
   ```yaml
   apiVersion: v1
   kind: Config
   clusters:
   - cluster:
       certificate-authority: /root/.minikube/ca.crt
       server: https://192.168.49.2:8443
     name: my-cluster
   contexts:
   - context:
       cluster: my-cluster
       namespace: default
       user: sa-name
     name: default-context
   current-context: default-context
   users:
   - name: sa-name
     user:
       token: <INSERT_YOUR_SERVICEACCOUNT_TOKEN_HERE>
   ```

---

## Setup Instructions

### 1. Apply RBAC Resources
Apply the YAML files to create the necessary RBAC resources:

```bash
kubectl apply -f role.yaml
kubectl apply -f rolebinding.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f secret.yaml
```

### 2. Retrieve the ServiceAccount Token
Run the following commands to get the token associated with the `sa-name` ServiceAccount:

```bash
SECRET_NAME=$(kubectl -n default get sa sa-name -o jsonpath="{.secrets[0].name}")
kubectl -n default get secret $SECRET_NAME -o jsonpath="{.data.token}" | base64 -d
```

Copy the output token for the next step.

### 3. Create the Kubeconfig File
1. Open the `kubeconfig` template file and replace `<INSERT_YOUR_SERVICEACCOUNT_TOKEN_HERE>` with the token retrieved in the previous step.
2. Save the file as `kubeconfig`.

### 4. Test the Configuration
Use the `kubeconfig` file to access the cluster:

```bash
kubectl --kubeconfig=kubeconfig get pods
```

If the command runs successfully, the configuration is correct.

---

## Notes
- The `ServiceAccount` token is used for authentication, while the `Role` and `RoleBinding` define the authorization rules.
- Ensure the `certificate-authority` path in the kubeconfig file points to the correct location of your CA certificate (`ca.crt`).

---

## Cleanup
To delete all the resources created in this guide, run:

```bash
kubectl delete sa sa-name -n default
kubectl delete role pod-reader -n default
kubectl delete rolebinding read-pods -n default
kubectl delete secret secret-sa-sample -n default
```

---

## Troubleshooting
- If you encounter a "Please enter Username" message, ensure the token is correctly added to the kubeconfig file under the `users` section.
- Verify the CA certificate path is correct in the kubeconfig file.

---

Happy Kubernetes management! 🚀
