
# Kubernetes PersistentVolume Examples: Local Provisioner, HostPath, and NFS

This guide demonstrates three different examples of PersistentVolume (PV) and PersistentVolumeClaim (PVC) configurations in Kubernetes: using a Local Provisioner, HostPath, and NFS.

---

## Example 1: Local Provisioner

### Step 1: Create the PV
Create a file named `local-provisioner-pv.yaml` with the following content:

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
          - <NODE_NAME> # Replace with the node name
```

Apply the PV:
```bash
kubectl apply -f local-provisioner-pv.yaml
```

### Step 2: Create the PVC
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

Apply the PVC:
```bash
kubectl apply -f local-provisioner-pvc.yaml
```

---

## Example 2: HostPath

### Step 1: Create the PV
Create a file named `hostpath-pv.yaml` with the following content:

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

Apply the PV:
```bash
kubectl apply -f hostpath-pv.yaml
```

### Step 2: Create the PVC
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

Apply the PVC:
```bash
kubectl apply -f hostpath-pvc.yaml
```

---

## Example 3: NFS Provisioner

### Step 1: Prepare the NFS Server
Set up an NFS server and create a shared directory:
```bash
sudo mkdir -p /srv/nfs/kubedata
sudo chmod 777 /srv/nfs/kubedata
sudo exportfs -rav
```

### Step 2: Create the PV
Create a file named `nfs-pv.yaml` with the following content:

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
  nfs:
    path: /srv/nfs/kubedata
    server: <NFS_SERVER_IP> # Replace with your NFS server IP
  storageClassName: nfs-storage
```

Apply the PV:
```bash
kubectl apply -f nfs-pv.yaml
```

### Step 3: Create the PVC
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

Apply the PVC:
```bash
kubectl apply -f nfs-pvc.yaml
```

---

## Verify Storage

Check the status of the PVCs:
```bash
kubectl get pvc
```

Use the PVCs in a Pod by creating a file named `pod-using-pvc.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - mountPath: "/usr/share/nginx/html"
      name: storage
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: <PVC_NAME> # Replace with the PVC name (e.g., local-pvc, hostpath-pvc, or nfs-pvc)
```

Apply the Pod:
```bash
kubectl apply -f pod-using-pvc.yaml
```

---

These examples demonstrate the flexibility of Kubernetes storage provisioning using local provisioners, HostPath, and NFS. Let me know if you need further assistance! 😊
