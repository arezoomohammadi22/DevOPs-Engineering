
# NFS Subdir External Provisioner Setup for Kubernetes

This guide provides step-by-step instructions to set up the NFS Subdir External Provisioner in Kubernetes, create a StorageClass, and dynamically provision PersistentVolumes (PVs) using NFS.

---

## **Step 1: Install the NFS Subdir External Provisioner**

Use Helm to install the NFS Subdir External Provisioner.

### **1. Add the Helm Repository**
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
```

### **2. Install the NFS Provisioner**
Replace `<NFS_SERVER_IP>` and `<NFS_SHARE_PATH>` with your NFS server's IP address and shared directory path.

```bash
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner   --set nfs.server=<NFS_SERVER_IP>   --set nfs.path=<NFS_SHARE_PATH>   --set storageClass.name=nfs-storage
```

- Example:
   ```bash
   helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner      --set nfs.server=10.211.55.40      --set nfs.path=/srv/nfs/kubedata      --set storageClass.name=nfs-storage
   ```

### **3. Verify Installation**
Check the status of the provisioner pod:
```bash
kubectl get pods
```

You should see a pod named something like:
```
nfs-provisioner-nfs-subdir-external-provisioner-<random-string>
```

Verify the `StorageClass`:
```bash
kubectl get storageclass
```

You should see an output similar to:
```
NAME           PROVISIONER                      RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION
nfs-storage    nfs-subdir-external-provisioner   Delete          Immediate           false
```

---

## **Step 2: Create a PersistentVolumeClaim (PVC)**

Create a PVC that requests storage from the `nfs-storage` StorageClass.

Create a file named `nfs-dynamic-pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-dynamic-pvc
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
  storageClassName: nfs-storage
```

Apply the PVC:
```bash
kubectl apply -f nfs-dynamic-pvc.yaml
```

Verify that the PVC is bound:
```bash
kubectl get pvc
```

---

## **Step 3: Use the PVC in a Pod**

Create a Pod that uses the dynamically provisioned PVC.

Create a file named `pod-using-nfs-dynamic-pvc.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nfs-dynamic-pvc-pod
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
      claimName: nfs-dynamic-pvc
```

Apply the Pod:
```bash
kubectl apply -f pod-using-nfs-dynamic-pvc.yaml
```

Verify the Pod:
```bash
kubectl get pods
```

Check the content of the mounted directory:
```bash
kubectl exec -it nfs-dynamic-pvc-pod -- sh -c "echo 'Hello NFS Dynamic Provisioning!' > /usr/share/nginx/html/index.html"
kubectl exec -it nfs-dynamic-pvc-pod -- cat /usr/share/nginx/html/index.html
```

---

## **Summary**
- The NFS Subdir External Provisioner automates the creation of PersistentVolumes using NFS.
- A StorageClass (`nfs-storage`) handles dynamic provisioning of PVs when PVCs are requested.
- A Pod can mount the dynamically provisioned PV using the PVC.

---

## **Cleanup**
To delete all the created resources:
```bash
helm uninstall nfs-provisioner
kubectl delete pvc nfs-dynamic-pvc
kubectl delete pod nfs-dynamic-pvc-pod
```

---

With this setup, NFS-based PersistentVolumes are dynamically provisioned and used seamlessly in Kubernetes.
