
# HostPath Kubernetes Setup

This guide demonstrates how to set up a HostPath PersistentVolume (PV), PersistentVolumeClaim (PVC), and a sample Pod in Kubernetes.

---

## Step 1: Create a PersistentVolume (PV)
Create a file named `hostpath-pv.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostpath-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /mnt/data
  storageClassName: manual
```

Apply:
```bash
kubectl apply -f hostpath-pv.yaml
```

---

## Step 2: Create a PersistentVolumeClaim (PVC)
Create a file named `hostpath-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hostpath-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
```

Apply:
```bash
kubectl apply -f hostpath-pvc.yaml
```

---

## Step 3: Create a Pod Using PVC
Create a file named `pod-using-hostpath-pvc.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pvc-pod
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - mountPath: "/usr/share/nginx/html"
      name: hostpath-storage
  volumes:
  - name: hostpath-storage
    persistentVolumeClaim:
      claimName: hostpath-pvc
```

Apply:
```bash
kubectl apply -f pod-using-hostpath-pvc.yaml
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
   kubectl exec -it hostpath-pvc-pod -- sh -c "echo 'Hello HostPath!' > /usr/share/nginx/html/index.html"
   kubectl exec -it hostpath-pvc-pod -- cat /usr/share/nginx/html/index.html
   ```

---

This setup demonstrates a functional HostPath storage setup in Kubernetes.
