
# NFS Kubernetes Setup

This guide demonstrates how to set up an NFS PersistentVolume (PV), PersistentVolumeClaim (PVC), and a sample Pod in Kubernetes.

---

## Step 1: Prepare the NFS Server
1. Install NFS:
   ```bash
   sudo apt update && sudo apt install -y nfs-kernel-server
   ```

2. Create a shared directory:
   ```bash
   sudo mkdir -p /srv/nfs/kubedata
   sudo chmod 777 /srv/nfs/kubedata
   ```

3. Export the directory:
   Add this to `/etc/exports`:
   ```plaintext
   /srv/nfs/kubedata *(rw,sync,no_subtree_check,no_root_squash)
   ```
   Then restart the NFS service:
   ```bash
   sudo exportfs -rav
   ```

---

## Step 2: Create a PersistentVolume (PV)
Create a file named `nfs-pv.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteMany
  storageClassName: nfs-storage
  nfs:
    path: /srv/nfs/kubedata
    server: <NFS_SERVER_IP> # Replace with your NFS server IP
```

Apply:
```bash
kubectl apply -f nfs-pv.yaml
```

---

## Step 3: Create a PersistentVolumeClaim (PVC)
Create a file named `nfs-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: nfs-storage
```

Apply:
```bash
kubectl apply -f nfs-pvc.yaml
```

---

## Step 4: Create a Pod Using PVC
Create a file named `pod-using-nfs-pvc.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nfs-pvc-pod
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - mountPath: "/usr/share/nginx/html"
      name: nfs-storage
  volumes:
  - name: nfs-storage
    persistentVolumeClaim:
      claimName: nfs-pvc
```

Apply:
```bash
kubectl apply -f pod-using-nfs-pvc.yaml
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
   kubectl exec -it nfs-pvc-pod -- sh -c "echo 'Hello NFS!' > /usr/share/nginx/html/index.html"
   kubectl exec -it nfs-pvc-pod -- cat /usr/share/nginx/html/index.html
   ```

---

This setup demonstrates a functional NFS storage setup in Kubernetes.
