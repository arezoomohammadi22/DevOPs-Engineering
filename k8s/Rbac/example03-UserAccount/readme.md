
# Kubernetes RBAC Configuration for User Ali

This guide explains how to configure Role-Based Access Control (RBAC) in Kubernetes for a user named Ali. It includes granting permissions to get and list pods and services in the `core` namespace and setting up a dedicated kubeconfig file for Ali.

---

## Example-02: Step 1 - Create a Role for Pods

Create a file named `role-get-pods.yaml` with the following content:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: core
  name: get-pods-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

This Role allows `get` and `list` operations on pods within the `core` namespace.

---

## Example-02: Step 2 - Create a RoleBinding

Create a file named `rolebinding-ali-get-pods.yaml` with the following content:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: get-pods-rolebinding
  namespace: core
subjects:
- kind: User
  name: ali # Replace with the actual username of Ali
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: get-pods-role
  apiGroup: rbac.authorization.k8s.io
```

---

## Example-02: Apply the Configuration

Apply the Role and RoleBinding to your Kubernetes cluster:

```bash
kubectl apply -f role-get-pods.yaml
kubectl apply -f rolebinding-ali-get-pods.yaml
```

---

## Example-02: Verify Access

To verify the access control works as intended, impersonate the user Ali and test access to pods:

```bash
kubectl auth can-i get pods --namespace=core --as=ali
```

This command should return **"yes"**, indicating Ali can get the pods in the `core` namespace.

Try the following command to ensure Ali cannot perform unauthorized actions like creating pods:

```bash
kubectl auth can-i create pods --namespace=core --as=ali
```

This command should return **"no"**.

---

## Example-02: Generate a Certificate for Ali

1. Generate a private key for Ali:
   ```bash
   openssl genrsa -out ali.key 2048
   ```

2. Create a Certificate Signing Request (CSR):
   ```bash
   openssl req -new -key ali.key -out ali.csr -subj "/CN=ali/O=team"
   ```

3. Sign the CSR with the Kubernetes CA:
   ```bash
   openssl x509 -req -in ali.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ali.crt -days 365
   ```

---

## Example-02: Create a Kubeconfig File for Ali

1. Get the Kubernetes API Server address:
   ```bash
   kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
   ```

2. Create a kubeconfig file named `ali-kubeconfig.yaml` with the following content:

   ```yaml
   apiVersion: v1
   kind: Config
   clusters:
   - cluster:
       certificate-authority: /path/to/ca.crt
       server: https://<K8S-API-SERVER>
     name: kubernetes
   contexts:
   - context:
       cluster: kubernetes
       user: ali
     name: ali-context
   current-context: ali-context
   users:
   - name: ali
     user:
       client-certificate: /path/to/ali.crt
       client-key: /path/to/ali.key
   ```

3. Share the `ali-kubeconfig.yaml` file with Ali. Ali can use this file to interact with the Kubernetes cluster:

   ```bash
   export KUBECONFIG=/path/to/ali-kubeconfig.yaml
   kubectl get pods --namespace=core
   ```

---

## Example-02: Grant Access to Both Pods and Services

### Step 1 - Update the Role

Modify the `role-get-pods.yaml` file to include services:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: core
  name: get-pods-services-role
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list"]
```

Save this file as `role-get-pods-services.yaml`.

### Step 2 - Create a RoleBinding for Pods and Services

Create a file named `rolebinding-ali-get-pods-services.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: get-pods-services-rolebinding
  namespace: core
subjects:
- kind: User
  name: ali # Replace with the actual username of Ali
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: get-pods-services-role
  apiGroup: rbac.authorization.k8s.io
```

Apply the new Role and RoleBinding:

```bash
kubectl apply -f role-get-pods-services.yaml
kubectl apply -f rolebinding-ali-get-pods-services.yaml
```

---

## Example-02: Verify Updated Access

Test that Ali can access both pods and services:

```bash
kubectl auth can-i get pods --namespace=core --as=ali
kubectl auth can-i get services --namespace=core --as=ali
```

Ali should have `get` and `list` permissions for both resources but no additional permissions.

---

By following these steps, Ali is granted limited access to specific resources in the `core` namespace while ensuring secure and controlled interactions with the Kubernetes cluster.
