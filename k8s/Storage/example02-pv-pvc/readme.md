
# Local Provisioner Kubernetes Setup

This guide demonstrates how to set up a Local Provisioner in Kubernetes with a PersistentVolume (PV), PersistentVolumeClaim (PVC), and a sample Pod.

---

## Step 1: Create a StorageClass
Create a file named `local-storage-class.yaml`:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

Apply:
```bash
kubectl apply -f local-storage-class.yaml
```

---

## Step 2: Create a PersistentVolume (PV)
Create a file named `local-provisioner-pv.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  storageClassName: local-storage
  local:
    path: /mnt/data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - <NODE_NAME> # Replace with your node name
```

Apply:
```bash
kubectl apply -f local-provisioner-pv.yaml
```

---

## Step 3: Create a PersistentVolumeClaim (PVC)
Create a file named `local-provisioner-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-storage
```

Apply:
```bash
kubectl apply -f local-provisioner-pvc.yaml
```

---

## Step 4: Create a Pod Using PVC
Create a file named `pod-using-local-pvc.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: local-pvc-pod
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - mountPath: "/usr/share/nginx/html"
      name: local-storage
  volumes:
  - name: local-storage
    persistentVolumeClaim:
      claimName: local-pvc
```

Apply:
```bash
kubectl apply -f pod-using-local-pvc.yaml
```

---

## Verification
1. **Check PVC Status**:
   ```bash
   kubectl get pvc
   ```

2. **Check Pod Status**:
   ```bash
   kubectl get pods
   ```

3. **Test Storage by Writing and Reading Data**:
   ```bash
   kubectl exec -it local-pvc-pod -- sh -c "echo 'Hello Local Storage!' > /usr/share/nginx/html/index.html"
   kubectl exec -it local-pvc-pod -- cat /usr/share/nginx/html/index.html
   ```

---

This setup demonstrates a functional Local Provisioner storage setup in Kubernetes.
