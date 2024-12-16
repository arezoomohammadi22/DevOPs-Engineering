
# Kubernetes Service Account with Token Authentication

This guide explains how to create a ServiceAccount in Kubernetes, generate a token for it, and use the token to authenticate with the Kubernetes API.

---

## Step 1 - Create a ServiceAccount

Create a file named `serviceaccount.yaml` with the following content:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  namespace: core
```

Apply the ServiceAccount:

```bash
kubectl apply -f serviceaccount.yaml
```

---

## Step 2 - Create a Role and RoleBinding

Define a Role and RoleBinding to grant the necessary permissions to the ServiceAccount. For example:

### Role
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: core
  name: service-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

### RoleBinding
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: service-rolebinding
  namespace: core
subjects:
- kind: ServiceAccount
  name: my-service-account
  namespace: core
roleRef:
  kind: Role
  name: service-role
  apiGroup: rbac.authorization.k8s.io
```

Apply the Role and RoleBinding:

```bash
kubectl apply -f role.yaml
kubectl apply -f rolebinding.yaml
```

---

## Step 3 - Generate a Token for the ServiceAccount

Create a Secret to store the ServiceAccount token:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-service-account-token
  namespace: core
  annotations:
    kubernetes.io/service-account.name: my-service-account
type: kubernetes.io/service-account-token
```

Apply the Secret:

```bash
kubectl apply -f secret.yaml
```

Retrieve the token:

```bash
kubectl get secret my-service-account-token -n core -o jsonpath="{.data.token}" | base64 --decode
```

Copy the token for use in your applications.

---

## Step 4 - Use the Token in Your Application

You can use the ServiceAccount token to authenticate your applications with the Kubernetes API. For example, using Python:

### Example: API Call to Kubernetes
```python
import requests

# Replace with your token and API server address
token = "YOUR_SERVICE_ACCOUNT_TOKEN"
api_server = "https://your-k8s-api-server"

# Example API call to get pods
headers = {
    "Authorization": f"Bearer {token}"
}
response = requests.get(f"{api_server}/api/v1/namespaces/core/pods", headers=headers, verify='/path/to/ca.crt')

# Print the response
print(response.json())
```

### Notes:
1. Replace `YOUR_SERVICE_ACCOUNT_TOKEN` with the token generated in Step 3.
2. Replace `/path/to/ca.crt` with the path to your Kubernetes CA certificate (`/etc/kubernetes/pki/ca.crt`).
3. Replace `your-k8s-api-server` with the API server address, which can be retrieved using:
   ```bash
   kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
   ```

---

By following these steps, you can use a ServiceAccount token to authenticate and interact with the Kubernetes API securely.
