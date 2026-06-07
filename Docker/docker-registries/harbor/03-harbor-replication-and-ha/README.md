# Harbor Private Registry on Kubernetes
### High Availability & Replication Lab Guide

A complete step-by-step guide to deploy **two Harbor instances** on a single Kubernetes cluster, configure **TLS with self-signed certificates**, expose via **NodePort**, and set up **image replication** between them.

> This guide is designed for students learning container registry management, HA concepts, and image replication workflows.

---

## What You Will Build

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                             │
│  ┌──────────────────────────┐  ┌──────────────────────────┐ │
│  │  namespace: harbor       │  │  namespace: harbor2      │ │
│  │                          │  │                          │ │
│  │  Harbor 1 (Primary)      │  │  Harbor 2 (Replica)      │ │
│  │  NodePort: 30443 (HTTPS) │  │  NodePort: 30543 (HTTPS) │ │
│  │  NodePort: 30080 (HTTP)  │  │  NodePort: 30580 (HTTP)  │ │
│  │                          │  │                          │ │
│  │  registry.sananetco.com  │  │  registry2.sananetco.com │ │
│  └────────────┬─────────────┘  └──────────────────────────┘ │
│               │   Push-based Replication (Event Based)       │
│               └──────────────────────────────────────────►  │
│                                                             │
│  Storage: Longhorn (all PVCs)                               │
└─────────────────────────────────────────────────────────────┘
```

**When you push an image to Harbor 1, it automatically replicates to Harbor 2.**  
This simulates a real-world DR (Disaster Recovery) or multi-datacenter setup.

---

## Table of Contents

**Part 1 — Harbor 1 (Primary)**
1. [Prerequisites](#1-prerequisites)
2. [Set Variables](#2-set-variables)
3. [Add Harbor Helm Repository](#3-add-harbor-helm-repository)
4. [Create Namespace](#4-create-namespace)
5. [Generate Self-Signed TLS Certificate for Harbor 1](#5-generate-self-signed-tls-certificate-for-harbor-1)
6. [Create Kubernetes TLS Secret for Harbor 1](#6-create-kubernetes-tls-secret-for-harbor-1)
7. [Create harbor-values.yaml](#7-create-harbor-valuesyaml)
8. [Install Harbor 1 with Helm](#8-install-harbor-1-with-helm)
9. [DNS / hosts Entry for Harbor 1](#9-dns--hosts-entry-for-harbor-1)
10. [Trust the CA Certificate for Harbor 1](#10-trust-the-ca-certificate-for-harbor-1)
11. [Verify Harbor 1](#11-verify-harbor-1)
12. [Test Push and Pull on Harbor 1](#12-test-push-and-pull-on-harbor-1)

**Part 2 — Harbor 2 (Replica)**

13. [Generate Self-Signed TLS Certificate for Harbor 2](#13-generate-self-signed-tls-certificate-for-harbor-2)
14. [Create Namespace and TLS Secret for Harbor 2](#14-create-namespace-and-tls-secret-for-harbor-2)
15. [Create harbor2-values.yaml](#15-create-harbor2-valuesyaml)
16. [Install Harbor 2 with Helm](#16-install-harbor-2-with-helm)
17. [DNS / hosts Entry for Harbor 2](#17-dns--hosts-entry-for-harbor-2)
18. [Trust the CA Certificate for Harbor 2](#18-trust-the-ca-certificate-for-harbor-2)
19. [Verify Harbor 2](#19-verify-harbor-2)

**Part 3 — Replication**

20. [Register Harbor 2 as an Endpoint in Harbor 1](#20-register-harbor-2-as-an-endpoint-in-harbor-1)
21. [Create Replication Rule](#21-create-replication-rule)
22. [Test Replication](#22-test-replication)
23. [Monitor Replication Status](#23-monitor-replication-status)

**Part 4 — High Availability**

24. [Scale Harbor Components for HA](#24-scale-harbor-components-for-ha)

**Part 5 — Reference**

25. [Troubleshooting](#25-troubleshooting)
26. [Summary Table](#26-summary-table)

---

# Part 1 — Harbor 1 (Primary)

---

## 1. Prerequisites

Make sure the following are ready before starting:

| Requirement | How to verify |
|-------------|--------------|
| Kubernetes cluster (v1.20+) | `kubectl get nodes` |
| Helm v3 installed | `helm version` |
| Longhorn installed | `kubectl get storageclass longhorn` |
| `openssl` installed | `openssl version` |
| `kubectl` configured | `kubectl cluster-info` |

> You do **not** need an Ingress controller — Harbor is exposed via NodePort directly.

---

## 2. Set Variables

Export these variables. Keep your terminal open or re-export them if you open a new session.

```bash
export HARBOR_HOSTNAME="registry.sananetco.com"
export HARBOR_NS="harbor"
```

---

## 3. Add Harbor Helm Repository

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
```

Verify:

```bash
helm repo list
```

You should see `harbor` pointing to `https://helm.goharbor.io`.

---

## 4. Create Namespace

```bash
kubectl create namespace harbor
```

Verify:

```bash
kubectl get namespace harbor
```

---

## 5. Generate Self-Signed TLS Certificate for Harbor 1

We create our own Certificate Authority (CA) and use it to sign the Harbor 1 server certificate. Run each command one by one.

**5.1 — Create directory for certificates**

```bash
mkdir -p ./harbor-certs
```

**5.2 — Generate CA private key**

```bash
openssl genrsa -out ./harbor-certs/ca.key 4096
```

**5.3 — Generate CA certificate (valid 10 years)**

```bash
openssl req -x509 -new -nodes \
  -key ./harbor-certs/ca.key \
  -sha256 -days 3650 \
  -out ./harbor-certs/ca.crt \
  -subj "/CN=Harbor-CA/O=Harbor"
```

**5.4 — Generate server private key**

```bash
openssl genrsa -out ./harbor-certs/harbor.key 4096
```

**5.5 — Create CSR configuration file**

The `subjectAltName` (SAN) field is required by Docker and modern browsers to trust the certificate.

```bash
cat > ./harbor-certs/harbor.cnf <<EOF
[req]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = req_ext

[dn]
CN = registry.sananetco.com

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = registry.sananetco.com
EOF
```

**5.6 — Generate Certificate Signing Request (CSR)**

```bash
openssl req -new \
  -key ./harbor-certs/harbor.key \
  -out ./harbor-certs/harbor.csr \
  -config ./harbor-certs/harbor.cnf
```

**5.7 — Create extension config file**

```bash
cat > ./harbor-certs/ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = registry.sananetco.com
EOF
```

**5.8 — Sign the server certificate with your CA**

```bash
openssl x509 -req \
  -in ./harbor-certs/harbor.csr \
  -CA ./harbor-certs/ca.crt \
  -CAkey ./harbor-certs/ca.key \
  -CAcreateserial \
  -out ./harbor-certs/harbor.crt \
  -days 3650 \
  -sha256 \
  -extfile ./harbor-certs/ext.cnf
```

**5.9 — Verify the certificate has the correct SAN**

```bash
openssl x509 -in ./harbor-certs/harbor.crt -text -noout | grep -A1 "Subject Alternative Name"
```

Expected output: `DNS:registry.sananetco.com`

Your `./harbor-certs/` directory now contains:

```
harbor-certs/
├── ca.crt       ← CA certificate (used to trust Harbor 1)
├── ca.key       ← CA private key
├── harbor.crt   ← Server certificate
├── harbor.key   ← Server private key
├── harbor.csr   ← Certificate signing request
├── harbor.cnf   ← CSR config
└── ext.cnf      ← Extension config
```

---

## 6. Create Kubernetes TLS Secret for Harbor 1

```bash
kubectl create secret tls harbor-tls \
  --cert=./harbor-certs/harbor.crt \
  --key=./harbor-certs/harbor.key \
  --namespace=harbor \
  --dry-run=client -o yaml | kubectl apply -f -
```

Verify:

```bash
kubectl get secret harbor-tls -n harbor
```

Expected output:

```
NAME         TYPE                DATA   AGE
harbor-tls   kubernetes.io/tls   2      5s
```

---

## 7. Create harbor-values.yaml

Copy and paste this entire block into your terminal:

```bash
cat > harbor-values.yaml <<'EOF'
# Harbor 1 — Primary Registry
# Storage: Longhorn | Expose: NodePort | SSL: TLS Secret

expose:
  type: nodePort
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls
  nodePort:
    name: harbor
    ports:
      http:
        port: 80
        nodePort: 30080
      https:
        port: 443
        nodePort: 30443

externalURL: https://registry.sananetco.com:30443

harborAdminPassword: "Harbor12345"

persistence:
  enabled: true
  resourcePolicy: "keep"
  persistentVolumeClaim:
    registry:
      storageClass: longhorn
      size: 50Gi
      accessMode: ReadWriteOnce
    jobservice:
      storageClass: longhorn
      size: 1Gi
      accessMode: ReadWriteOnce
    database:
      storageClass: longhorn
      size: 5Gi
      accessMode: ReadWriteOnce
    redis:
      storageClass: longhorn
      size: 1Gi
      accessMode: ReadWriteOnce
    trivy:
      storageClass: longhorn
      size: 5Gi
      accessMode: ReadWriteOnce

portal:
  replicas: 1
core:
  replicas: 1
jobservice:
  replicas: 1
registry:
  replicas: 1
trivy:
  enabled: true
  replicas: 1
EOF
```

---

## 8. Install Harbor 1 with Helm

```bash
helm install harbor harbor/harbor \
  --namespace harbor \
  --values harbor-values.yaml \
  --wait \
  --timeout 10m
```

Monitor pods in a second terminal:

```bash
watch kubectl get pods -n harbor
```

Wait until all pods show `Running`. This takes **3–5 minutes** depending on Longhorn provisioning speed.

Check PVCs are all bound:

```bash
kubectl get pvc -n harbor
```

---

## 9. DNS / hosts Entry for Harbor 1

Get a worker node IP:

```bash
kubectl get nodes -o wide
```

**Option A — Real DNS:** Create an `A` record: `registry.sananetco.com → <NODE-IP>`

**Option B — /etc/hosts (lab/testing):** On every machine that needs access:

```bash
echo "<NODE-IP>  registry.sananetco.com" | sudo tee -a /etc/hosts
```

---

## 10. Trust the CA Certificate for Harbor 1

Run on **every Kubernetes worker node**:

```bash
sudo mkdir -p /etc/docker/certs.d/registry.sananetco.com:30443
sudo cp ./harbor-certs/ca.crt /etc/docker/certs.d/registry.sananetco.com:30443/ca.crt
sudo systemctl restart docker
```

For clusters using **containerd**:

```bash
sudo mkdir -p /etc/containerd/certs.d/registry.sananetco.com:30443
sudo cp ./harbor-certs/ca.crt /etc/containerd/certs.d/registry.sananetco.com:30443/ca.crt
sudo systemctl restart containerd
```

On your **local Linux machine**:

```bash
sudo cp ./harbor-certs/ca.crt /usr/local/share/ca-certificates/harbor-ca.crt
sudo update-ca-certificates
sudo systemctl restart docker
```

On your **local macOS machine**:

```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain ./harbor-certs/ca.crt
# Restart Docker Desktop manually
```

---

## 11. Verify Harbor 1

```bash
kubectl get svc -n harbor
```

```bash
curl -k https://registry.sananetco.com:30443/api/v2.0/ping
```

Expected: `"Pong"`

Open the UI in your browser:
```
https://registry.sananetco.com:30443
```
- Username: `admin`
- Password: `Harbor12345`

---

## 12. Test Push and Pull on Harbor 1

**Login:**
```bash
docker login registry.sananetco.com:30443 -u admin -p Harbor12345
```

**Pull a test image:**
```bash
docker pull nginx:alpine
```

**Tag for Harbor 1:**
```bash
docker tag nginx:alpine registry.sananetco.com:30443/library/nginx:test
```

**Push to Harbor 1:**
```bash
docker push registry.sananetco.com:30443/library/nginx:test
```

**Pull back from Harbor 1:**
```bash
docker rmi registry.sananetco.com:30443/library/nginx:test
docker pull registry.sananetco.com:30443/library/nginx:test
```

Harbor 1 is fully operational. ✅

---

# Part 2 — Harbor 2 (Replica)

Harbor 2 is a **second, independent Harbor instance** in a different namespace. It acts as the replication destination — images pushed to Harbor 1 will automatically appear here.

---

## 13. Generate Self-Signed TLS Certificate for Harbor 2

**13.1 — Create directory**

```bash
mkdir -p ./harbor2-certs
```

**13.2 — Generate CA private key**

```bash
openssl genrsa -out ./harbor2-certs/ca.key 4096
```

**13.3 — Generate CA certificate**

```bash
openssl req -x509 -new -nodes \
  -key ./harbor2-certs/ca.key \
  -sha256 -days 3650 \
  -out ./harbor2-certs/ca.crt \
  -subj "/CN=Harbor2-CA/O=Harbor"
```

**13.4 — Generate server private key**

```bash
openssl genrsa -out ./harbor2-certs/harbor.key 4096
```

**13.5 — Create CSR configuration file**

```bash
cat > ./harbor2-certs/harbor.cnf <<EOF
[req]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = req_ext

[dn]
CN = registry2.sananetco.com

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = registry2.sananetco.com
EOF
```

**13.6 — Generate CSR**

```bash
openssl req -new \
  -key ./harbor2-certs/harbor.key \
  -out ./harbor2-certs/harbor.csr \
  -config ./harbor2-certs/harbor.cnf
```

**13.7 — Create extension config file**

```bash
cat > ./harbor2-certs/ext.cnf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = registry2.sananetco.com
EOF
```

**13.8 — Sign the certificate**

```bash
openssl x509 -req \
  -in ./harbor2-certs/harbor.csr \
  -CA ./harbor2-certs/ca.crt \
  -CAkey ./harbor2-certs/ca.key \
  -CAcreateserial \
  -out ./harbor2-certs/harbor.crt \
  -days 3650 \
  -sha256 \
  -extfile ./harbor2-certs/ext.cnf
```

**13.9 — Verify**

```bash
openssl x509 -in ./harbor2-certs/harbor.crt -text -noout | grep -A1 "Subject Alternative Name"
```

Expected: `DNS:registry2.sananetco.com`

---

## 14. Create Namespace and TLS Secret for Harbor 2

```bash
kubectl create namespace harbor2
```

```bash
kubectl create secret tls harbor-tls \
  --cert=./harbor2-certs/harbor.crt \
  --key=./harbor2-certs/harbor.key \
  --namespace=harbor2 \
  --dry-run=client -o yaml | kubectl apply -f -
```

Verify:

```bash
kubectl get secret harbor-tls -n harbor2
```

---

## 15. Create harbor2-values.yaml

> Notice the **different NodePorts** (30543 / 30580) to avoid conflict with Harbor 1.

```bash
cat > harbor2-values.yaml <<'EOF'
# Harbor 2 — Replica Registry
# Storage: Longhorn | Expose: NodePort | SSL: TLS Secret

expose:
  type: nodePort
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls
  nodePort:
    name: harbor2
    ports:
      http:
        port: 80
        nodePort: 30580
      https:
        port: 443
        nodePort: 30543

externalURL: https://registry2.sananetco.com:30543

harborAdminPassword: "Harbor12345"

persistence:
  enabled: true
  resourcePolicy: "keep"
  persistentVolumeClaim:
    registry:
      storageClass: longhorn
      size: 20Gi
      accessMode: ReadWriteOnce
    jobservice:
      storageClass: longhorn
      size: 1Gi
      accessMode: ReadWriteOnce
    database:
      storageClass: longhorn
      size: 5Gi
      accessMode: ReadWriteOnce
    redis:
      storageClass: longhorn
      size: 1Gi
      accessMode: ReadWriteOnce
    trivy:
      storageClass: longhorn
      size: 5Gi
      accessMode: ReadWriteOnce

portal:
  replicas: 1
core:
  replicas: 1
jobservice:
  replicas: 1
registry:
  replicas: 1
trivy:
  enabled: true
  replicas: 1
EOF
```

---

## 16. Install Harbor 2 with Helm

```bash
helm install harbor2 harbor/harbor \
  --namespace harbor2 \
  --values harbor2-values.yaml \
  --wait \
  --timeout 10m
```

Monitor pods:

```bash
watch kubectl get pods -n harbor2
```

Check PVCs:

```bash
kubectl get pvc -n harbor2
```

---

## 17. DNS / hosts Entry for Harbor 2

```bash
echo "<NODE-IP>  registry2.sananetco.com" | sudo tee -a /etc/hosts
```

Use the same node IP as Harbor 1 — both are on the same cluster, different ports.

---

## 18. Trust the CA Certificate for Harbor 2

On **every Kubernetes worker node**:

```bash
sudo mkdir -p /etc/docker/certs.d/registry2.sananetco.com:30543
sudo cp ./harbor2-certs/ca.crt /etc/docker/certs.d/registry2.sananetco.com:30543/ca.crt
sudo systemctl restart docker
```

For **containerd**:

```bash
sudo mkdir -p /etc/containerd/certs.d/registry2.sananetco.com:30543
sudo cp ./harbor2-certs/ca.crt /etc/containerd/certs.d/registry2.sananetco.com:30543/ca.crt
sudo systemctl restart containerd
```

On your **local machine**:

```bash
sudo cp ./harbor2-certs/ca.crt /usr/local/share/ca-certificates/harbor2-ca.crt
sudo update-ca-certificates
sudo systemctl restart docker
```

---

## 19. Verify Harbor 2

```bash
curl -k https://registry2.sananetco.com:30543/api/v2.0/ping
```

Expected: `"Pong"`

Open the UI:
```
https://registry2.sananetco.com:30543
```
- Username: `admin`
- Password: `Harbor12345`

Harbor 2 is running. ✅

---

# Part 3 — Replication

Now we connect Harbor 1 and Harbor 2. We configure Harbor 1 to **automatically push** any image it receives into Harbor 2.

---

## 20. Register Harbor 2 as an Endpoint in Harbor 1

Open Harbor 1 UI: `https://registry.sananetco.com:30443`

Navigate to: **Administration → Registries → NEW ENDPOINT**

Fill in the form:

| Field | Value |
|-------|-------|
| **Provider** | `Harbor` |
| **Name** | `harbor2-replica` |
| **Endpoint URL** | `https://registry2.sananetco.com:30543` |
| **Access ID** | `admin` |
| **Access Secret** | `Harbor12345` |
| **Verify Remote Cert** | ❌ Uncheck (self-signed cert) |

Click **TEST CONNECTION**

✅ You should see: `Connection tested successfully`

Click **OK** to save.

---

## 21. Create Replication Rule

Navigate to: **Administration → Replications → NEW REPLICATION RULE**

Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `push-to-harbor2` |
| **Description** | Replicate all images to Harbor 2 |
| **Replication Mode** | `Push-based` |
| **Source resource filter → Name** | `**` (all images) |
| **Source resource filter → Tag** | `**` (all tags) |
| **Destination Registry** | `harbor2-replica` |
| **Destination Namespace** | leave empty (keeps same project name) |
| **Trigger Mode** | `Event Based` |
| **Override** | ✅ Check |
| **Enable rule** | ✅ Check |

Click **SAVE**

> **Trigger Mode explained:**
> - `Event Based` — replicates automatically every time an image is pushed ← use this
> - `Manual` — you trigger it yourself each time
> - `Scheduled` — runs on a cron schedule (e.g. every night at 2am)

---

## 22. Test Replication

Push a new image to Harbor 1:

```bash
docker login registry.sananetco.com:30443 -u admin -p Harbor12345
docker pull alpine:latest
docker tag alpine:latest registry.sananetco.com:30443/library/alpine:test
docker push registry.sananetco.com:30443/library/alpine:test
```

Wait **10–30 seconds**, then check Harbor 2 UI:

```
https://registry2.sananetco.com:30543
```

Navigate to: **Projects → library → Repositories**

You should see `library/alpine` with tag `test` — replicated automatically. ✅

Pull the image directly from Harbor 2 to confirm:

```bash
docker pull registry2.sananetco.com:30543/library/alpine:test
```

---

## 23. Monitor Replication Status

In Harbor 1 UI navigate to:

**Administration → Replications → push-to-harbor2**

Click on the rule name, then open the **Executions** tab.

Each row is one replication run. Columns:

| Column | Meaning |
|--------|---------|
| **Status** | `Succeeded` / `Failed` / `In Progress` |
| **Trigger** | `Event` (auto) or `Manual` |
| **Start Time** | When it started |
| **Duration** | How long it took |

Click on any execution row → **Logs** tab to see exactly which images were replicated and any errors.

---

# Part 4 — High Availability

To make Harbor resilient to pod failures, scale up the number of replicas for each component.

---

## 24. Scale Harbor Components for HA

Edit `harbor-values.yaml` and update the replica counts:

```yaml
portal:
  replicas: 2
core:
  replicas: 2
jobservice:
  replicas: 2
registry:
  replicas: 2
trivy:
  replicas: 2
```

> **Important:** When scaling `registry` to more than 1 replica, it needs shared storage. Change the registry PVC `accessMode` from `ReadWriteOnce` to `ReadWriteMany` — Longhorn supports this:
>
> ```yaml
> persistence:
>   persistentVolumeClaim:
>     registry:
>       storageClass: longhorn
>       size: 50Gi
>       accessMode: ReadWriteMany   # ← change this
> ```

Apply the changes with Helm upgrade:

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor \
  --values harbor-values.yaml
```

Verify pods scaled up:

```bash
kubectl get pods -n harbor
```

You should see 2 pods for each component (e.g. `harbor-core-xxx` × 2, `harbor-portal-xxx` × 2).

Check that pods are spread across different nodes (important for real HA):

```bash
kubectl get pods -n harbor -o wide
```

The `NODE` column should show different node names for each pair of replicas.

Do the same for Harbor 2 if you want HA on the replica side as well:

```bash
helm upgrade harbor2 harbor/harbor \
  --namespace harbor2 \
  --values harbor2-values.yaml
```

---

# Part 5 — Reference

---

## 25. Troubleshooting

### Pods stuck in `Pending`

```bash
kubectl describe pod <pod-name> -n harbor
kubectl get pvc -n harbor
kubectl get pods -n longhorn-system
```

Usually a Longhorn provisioning delay — wait 2–3 minutes and check again.

### `x509: certificate signed by unknown authority`

The CA cert is not trusted on that machine. Repeat the trust steps from [Step 10](#10-trust-the-ca-certificate-for-harbor-1) or [Step 18](#18-trust-the-ca-certificate-for-harbor-2).

### Helm install fails: `expected at most two arguments`

You have extra arguments in the command. Use exactly:
```bash
helm install harbor harbor/harbor --namespace harbor --values harbor-values.yaml --wait --timeout 10m
```

### Replication status shows `Failed`

```bash
# Check Harbor 1 jobservice logs
kubectl logs -n harbor -l component=jobservice --tail=50

# Check the endpoint connection in UI
# Administration → Registries → TEST button
```

Most common cause: Harbor 2 CA cert not trusted by Harbor 1 pods. Make sure you unchecked **Verify Remote Cert** when creating the endpoint.

### `502 Bad Gateway` in browser

Harbor pods are still starting up. Wait 1–2 minutes and refresh. Check:

```bash
kubectl logs -n harbor -l component=core --tail=30
kubectl logs -n harbor -l component=portal --tail=30
```

### Re-install Harbor 1 cleanly

```bash
helm uninstall harbor -n harbor
kubectl delete pvc --all -n harbor
kubectl delete namespace harbor
```

### Re-install Harbor 2 cleanly

```bash
helm uninstall harbor2 -n harbor2
kubectl delete pvc --all -n harbor2
kubectl delete namespace harbor2
```

---

## 26. Summary Table

| | Harbor 1 (Primary) | Harbor 2 (Replica) |
|--|-------------------|-------------------|
| **Namespace** | `harbor` | `harbor2` |
| **Helm release** | `harbor` | `harbor2` |
| **URL** | `https://registry.sananetco.com:30443` | `https://registry2.sananetco.com:30543` |
| **HTTP NodePort** | `30080` | `30580` |
| **HTTPS NodePort** | `30443` | `30543` |
| **Admin user** | `admin` | `admin` |
| **Admin password** | `Harbor12345` | `Harbor12345` |
| **TLS Secret** | `harbor-tls` in `harbor` | `harbor-tls` in `harbor2` |
| **CA cert** | `./harbor-certs/ca.crt` | `./harbor2-certs/ca.crt` |
| **Storage class** | `longhorn` | `longhorn` |
| **Registry PVC** | `50Gi` | `20Gi` |
| **Role** | Push images here | Receives replicated images |

### Replication Summary

| Setting | Value |
|---------|-------|
| **Rule name** | `push-to-harbor2` |
| **Mode** | Push-based |
| **Trigger** | Event Based (on every push) |
| **Source filter** | `**` (all images and tags) |
| **Destination** | `harbor2-replica` endpoint |

---

> **Change admin password after first login:**  
> UI → top-right user menu → `Change Password`  
> or via API:
> ```bash
> curl -k -u admin:Harbor12345 \
>   -X PUT "https://registry.sananetco.com:30443/api/v2.0/users/1/password" \
>   -H "Content-Type: application/json" \
>   -d '{"old_password":"Harbor12345","new_password":"YourNewPassword123"}'
> ```
