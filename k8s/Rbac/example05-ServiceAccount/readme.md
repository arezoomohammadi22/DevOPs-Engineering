# Kubernetes RBAC Example: ServiceAccount with API Access

This guide demonstrates how to configure a Kubernetes ServiceAccount with restricted permissions to access the API server using RBAC.

---

## **Scenario**
We want to:
1. Create a **ServiceAccount** named `api-reader-sa` in the `dev` namespace.
2. Grant the ServiceAccount **read-only permissions** to Pods, Services, and Deployments using a **Role** and **RoleBinding**.
3. Generate a token for the ServiceAccount.
4. Configure a custom `kubeconfig` file to use the ServiceAccount token for API interactions.

---

## **Step 1: Create the ServiceAccount**
Create a file named `serviceaccount.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-reader-sa
  namespace: dev
```

Apply the ServiceAccount:
```bash
kubectl apply -f serviceaccount.yaml
```

---

## **Step 2: Create a Role**
Create a file named `role-api-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-reader-role
  namespace: dev
rules:
- apiGroups: [""]   # Core API group
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
```

Apply the Role:
```bash
kubectl apply -f role-api-reader.yaml
```

---

## **Step 3: Bind the Role to the ServiceAccount**
Create a file named `rolebinding-api-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: api-reader-rolebinding
  namespace: dev
subjects:
- kind: ServiceAccount
  name: api-reader-sa
  namespace: dev
roleRef:
  kind: Role
  name: api-reader-role
  apiGroup: rbac.authorization.k8s.io
```

Apply the RoleBinding:
```bash
kubectl apply -f rolebinding-api-reader.yaml
```

---

## **Step 4: Generate a Token for the ServiceAccount**
1. Create a secret for the ServiceAccount.

Create a file named `sa-token-secret.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-reader-token
  namespace: dev
  annotations:
    kubernetes.io/service-account.name: "api-reader-sa"
type: kubernetes.io/service-account-token
```

Apply the Secret:
```bash
kubectl apply -f sa-token-secret.yaml
```

2. Retrieve the token:
```bash
kubectl get secret api-reader-token -n dev -o jsonpath="{.data.token}" | base64 --decode
```

3. Retrieve the Kubernetes CA certificate:
```bash
kubectl get secret api-reader-token -n dev -o jsonpath="{.data['ca\.crt']}" | base64 --decode > ca.crt
```

---

## **Step 5: Configure Kubeconfig**
Create a custom kubeconfig file `api-reader-kubeconfig.yaml` to authenticate using the ServiceAccount.

Replace placeholders `<KUBERNETES_API_SERVER>` and `<SERVICE_ACCOUNT_TOKEN>`:

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <BASE64_ENCODED_CA_CERT>
    server: https://<KUBERNETES_API_SERVER>
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: api-reader-sa
    namespace: dev
  name: api-reader-context
current-context: api-reader-context
users:
- name: api-reader-sa
  user:
    token: <SERVICE_ACCOUNT_TOKEN>
```

- Get the API server address:
   ```bash
   kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
   ```

- Encode the `ca.crt` content to base64:
   ```bash
   cat ca.crt | base64 -w 0
   ```

---

## **Step 6: Test API Access**
1. Export the kubeconfig file:
   ```bash
   export KUBECONFIG=./api-reader-kubeconfig.yaml
   ```

2. Use `kubectl` to test access to resources in the `dev` namespace:
   ```bash
   kubectl get pods -n dev
   kubectl get services -n dev
   kubectl get deployments -n dev
   ```

3. Verify that write operations are not permitted:
   ```bash
   kubectl delete pod <POD_NAME> -n dev
   ```
   You should see a "forbidden" error.

---

## **Summary**
- **ServiceAccount**: `api-reader-sa` created in the `dev` namespace.
- **Role**: Read-only access to Pods, Services, and Deployments.
- **RoleBinding**: Associated the Role with the ServiceAccount.
- **Custom Kubeconfig**: Allows access to the Kubernetes API using the ServiceAccount token.

This setup demonstrates fine-grained RBAC control and how to authenticate Kubernetes API requests using a ServiceAccount.

---

## **Cleanup**
To delete all created resources:
```bash
kubectl delete serviceaccount api-reader-sa -n dev
kubectl delete role api-reader-role -n dev
kubectl delete rolebinding api-reader-rolebinding -n dev
kubectl delete secret api-reader-token -n dev
```
