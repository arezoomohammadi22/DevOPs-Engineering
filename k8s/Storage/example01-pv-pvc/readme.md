# Kubernetes NFS Shared Volume Setup

This guide demonstrates how to mount a shared NFS volume into a Kubernetes Pod using a static PersistentVolume (PV) and PersistentVolumeClaim (PVC).

---

## 📁 Files Overview

- `nfs-pv.yaml`: Defines the static PersistentVolume backed by an NFS server.
- `nfs-pvc.yaml`: Declares the PersistentVolumeClaim that binds to the above PV.
- `nfs-pod.yaml`: A simple Pod that mounts the PVC at `/mnt/data`.

---

## 1️⃣ Prerequisites

- A running NFS server at IP `10.211.55.57`.
- The NFS export path `/data` must be:
  - Exported properly in `/etc/exports`
  - Accessible from all Kubernetes nodes
  - With permissions for the clients

Example on the NFS server:
```bash
sudo exportfs -v
# Expected output includes:
/data  *(rw,sync,no_root_squash)
```

---

## 2️⃣ Apply the Manifests

```bash
# Create the PersistentVolume
kubectl apply -f nfs-pv.yaml

# Create the PersistentVolumeClaim
kubectl apply -f nfs-pvc.yaml

# Create the test Pod
kubectl apply -f nfs-pod.yaml
```

---

## 3️⃣ Verify

```bash
# Check that the PV is bound
kubectl get pv

# Check that the PVC is bound
kubectl get pvc

# Check that the pod is running
kubectl get pods

# Exec into the Pod and test write access
kubectl exec -it nfs-test-pod -- sh

# Inside the container:
echo "hello from NFS" > /mnt/data/hello.txt
cat /mnt/data/hello.txt
```

---

## 📌 Notes

- `accessModes: ReadWriteMany` allows multiple pods or nodes to mount this NFS volume simultaneously.
- The `persistentVolumeReclaimPolicy: Retain` means the volume data will persist even after the PVC is deleted.
- You can mount the same PVC into multiple pods **at the same time**.

---

## 🔁 Reuse the PV with Multiple PVCs

By default, one PV binds to one PVC.  
To have **two PVCs** access the **same NFS path**, you can:

1. Duplicate the PV with a different name (e.g., `nfs-pv-2`) but the same NFS `path`.
2. Create a second PVC (e.g., `nfs-pvc-2`) that binds to it via `volumeName`.

Be cautious of write conflicts if the apps are not designed for shared storage.

---

## 🧼 Cleanup

```bash
kubectl delete pod nfs-test-pod
kubectl delete pvc nfs-pvc
kubectl delete pv nfs-pv
```
