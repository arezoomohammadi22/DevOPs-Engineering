# 🗄️ NFS Subdir External Provisioner for Kubernetes

This repository documents how to set up the [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) to enable dynamic NFS-based persistent volume provisioning in a Kubernetes cluster using Helm.

---

## ✅ Prerequisites

- A running NFS server (in this guide: `10.211.55.56`)
- A shared NFS export path (e.g., `/srv/nfs/k8s`)
- Kubernetes cluster (tested on kubeadm with 1 master and 1+ workers)
- NFS client (`nfs-common`) installed on **all nodes**

```bash
sudo apt update
sudo apt install -y nfs-common
```

---

## 🧠 Architecture Overview

- Helm deploys a dynamic provisioner pod that watches for PVCs.
- It mounts a shared NFS path and creates subdirectories for each claim.
- All PVCs get a unique subfolder under `/srv/nfs/k8s`.

---

## 🚀 Installation via Helm

### Step 1: Add Helm repo and update

```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
```

### Step 2: Create namespace

```bash
kubectl create namespace nfs-provisioner
```

### Step 3: Install the provisioner

```bash
helm install nfs-client nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace nfs-provisioner \
  --set nfs.server=10.211.55.56 \
  --set nfs.path=/srv/nfs/k8s \
  --set storageClass.name=nfs-client \
  --set storageClass.defaultClass=true
```

---

## 📦 StorageClass (auto-created)

If installed with Helm, a `StorageClass` named `nfs-client` is created with the following config:

```yaml
provisioner: nfs-subdir-external-provisioner
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

You can use it in your PVCs like this 👇

---

## 📄 Example: PVC + Pod

### pvc.yaml

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
```

### pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-nfs
spec:
  containers:
    - name: busybox
      image: busybox
      command: ["sleep", "3600"]
      volumeMounts:
        - name: nfs-vol
          mountPath: /data
  volumes:
    - name: nfs-vol
      persistentVolumeClaim:
        claimName: nfs-pvc
```

Apply them:

```bash
kubectl apply -f pvc.yaml
kubectl apply -f pod.yaml
```

---

## ✅ Test the Setup

1. Enter the pod:

```bash
kubectl exec -it test-nfs -- sh
```

2. Write a test file:

```bash
echo "Hello from NFS" > /data/hello.txt
cat /data/hello.txt
```

3. Check on your NFS server (`10.211.55.56`):

```bash
ls /srv/nfs/k8s/
cat /srv/nfs/k8s/*/hello.txt
```

You should see the file inside the dynamically created subdirectory.

---

## 📌 Notes

- This provisioner is **not CSI-based** but works very reliably for basic shared NFS use cases.
- It is ideal for development clusters or shared storage setups where CSI is overkill.
- The storageClass `nfs-client` is now the **default**, so PVCs can omit `storageClassName`.

---

## 📚 References

- [NFS Subdir External Provisioner GitHub](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)
- [Helm Chart Repo](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/tree/master/charts)

---

Happy provisioning! 🚀
