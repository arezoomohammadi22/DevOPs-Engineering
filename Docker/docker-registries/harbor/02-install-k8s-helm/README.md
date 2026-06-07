# Installing Harbor on Kubernetes with Helm and NGINX Ingress

This README is a practical, step-by-step installation guide for deploying **Harbor Registry** on a Kubernetes cluster using the **official Harbor Helm chart** and exposing it through **NGINX Ingress Controller**.

It is written for students and can be used as a GitHub README for a DevOps class lab.

The guide covers:

- Helm repository and chart version
- Kubernetes namespace creation
- NGINX Ingress exposure with `ingressClassName: nginx`
- HTTPS/TLS setup
- `values-harbor.yaml` configuration
- Docker login, image tag, push, and pull
- Kubernetes private image pull with `imagePullSecret`
- Public certificate vs private/self-signed certificate
- HTTP/insecure registry lab mode
- Robot accounts for CI/CD
- Upgrade, rollback, cleanup, and troubleshooting

---

## 1. Target Scenario

We want to deploy Harbor in this shape:

```text
Developer / CI Runner
        |
        | docker login / docker push
        v
https://harbor.example.com
        |
        v
NGINX Ingress Controller
        |
        v
Harbor services inside Kubernetes
        ^
        |
        | image pull by kubelet/container runtime
        |
Kubernetes Worker Nodes
```

Assumptions used in this guide:

| Item | Example Value |
|---|---|
| Harbor domain | `harbor.example.com` |
| Harbor namespace | `harbor` |
| NGINX Ingress class | `nginx` |
| TLS secret name | `harbor-tls` |
| Demo project in Harbor | `devops-demo` |
| Demo app namespace | `demo-app` |
| StorageClass example | `longhorn` |
| Harbor Helm chart version used in this guide | `1.19.1` |
| Harbor OSS app version from that chart | `2.15.1` |

Replace these values with your real environment values before running the commands.

> Always verify the newest available chart version before recording or running a real installation.

---

## 2. Prerequisites

Before installing Harbor, make sure you have:

- A working Kubernetes cluster
- `kubectl` configured for the target cluster
- Helm 3 installed
- NGINX Ingress Controller already installed
- An IngressClass named `nginx`
- A DNS record for Harbor, for example `harbor.example.com`
- A StorageClass for PVCs, for example Longhorn, NFS, Ceph, or a cloud storage provisioner
- A TLS certificate for HTTPS, or cert-manager configured to create one

Check the cluster:

```bash
kubectl cluster-info
kubectl get nodes -o wide
```

Check Helm:

```bash
helm version
```

Check IngressClass:

```bash
kubectl get ingressclass
```

Check the NGINX Ingress Controller service:

```bash
kubectl get svc -n ingress-nginx
```

If there is no IngressClass named `nginx`, either the NGINX Ingress Controller is not installed, or its class name is different. This guide assumes the correct class name is `nginx`.

---

## 3. DNS Preparation

Harbor needs a stable external DNS name because the registry hostname becomes part of image names.

Example image name:

```text
harbor.example.com/devops-demo/nginx:alpine
```

In a real environment, create a DNS record like this:

```text
harbor.example.com  A  <EXTERNAL-IP-OF-NGINX-INGRESS>
```

Find the external IP of the NGINX Ingress Controller:

```bash
kubectl get svc -n ingress-nginx
```

If the service type is `LoadBalancer`, use the `EXTERNAL-IP` value. In bare-metal environments, you may use MetalLB, NodePort, or an external load balancer.

The important point is:

> `harbor.example.com` must resolve to the entry point where NGINX Ingress receives traffic.

---

## 4. Add the Official Harbor Helm Repository

Use the official Harbor Helm chart repository:

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
```

List available versions:

```bash
helm search repo harbor/harbor --versions | head -10
```

Chart version and application version are not the same thing.

- Chart version: version of the Helm chart
- App version: version of Harbor deployed by that chart

For this guide:

```bash
CHART_VERSION="1.19.1"
```

In the source lesson, this chart version maps to Harbor OSS `2.15.1`. Before teaching or production use, verify the version again with `helm search repo` and check the official release notes.

---

## 5. Create the Harbor Namespace

Create a dedicated namespace:

```bash
kubectl create namespace harbor
```

If it already exists, verify it:

```bash
kubectl get ns harbor
```

A separate namespace makes Harbor easier to manage, monitor, back up, and clean up.

---

## 6. HTTPS or HTTP?

This is one of the most important decisions.

Docker, containerd, and Kubernetes expect registries to use **HTTPS by default**. This is intentional because container images are part of the software supply chain.

Recommended production path:

```text
https://harbor.example.com
```

There are three practical modes:

| Mode | Description | Recommended? |
|---|---|---:|
| HTTPS with public trusted certificate | Best option. Docker, browser, CI runners, and Kubernetes nodes usually trust it automatically. | Yes |
| HTTPS with private CA or self-signed certificate | Works, but the CA must be trusted on developers' machines, CI runners, and all worker nodes. | Acceptable if managed correctly |
| HTTP / insecure registry | Requires Docker/containerd insecure registry configuration. | Lab only |

For this guide, the main path is HTTPS.

---

## 7. Create a TLS Secret for NGINX Ingress

If you already have certificate files, create a Kubernetes TLS Secret in the `harbor` namespace.

Expected files:

```text
fullchain.pem
privkey.pem
```

Create the secret:

```bash
kubectl -n harbor create secret tls harbor-tls \
  --cert=fullchain.pem \
  --key=privkey.pem
```

Verify it:

```bash
kubectl -n harbor get secret harbor-tls
```

This secret will be referenced by the Harbor Helm values file.

---

## 8. Optional: cert-manager Certificate Example

If cert-manager is installed, you can let cert-manager create and renew the TLS secret.

Example file: `cert-manager-certificate.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: harbor-cert
  namespace: harbor
spec:
  secretName: harbor-tls
  dnsNames:
    - harbor.example.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

Apply it:

```bash
kubectl apply -f cert-manager-certificate.yaml
kubectl -n harbor get certificate
kubectl -n harbor get secret harbor-tls
```

For a serious lab or production environment, cert-manager is cleaner because it can handle certificate renewal.

---

## 9. Create `values-harbor.yaml`

Create the Helm values file.

> Replace `harbor.example.com`, `longhorn`, and the admin password before using this in a real environment.

```bash
cat > values-harbor.yaml <<'EOF'
expose:
  type: ingress
  tls:
    enabled: true
    certSource: secret
    secret:
      secretName: harbor-tls
  ingress:
    className: nginx
    hosts:
      core: harbor.example.com
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "600"

externalURL: https://harbor.example.com

harborAdminPassword: "ChangeThisPassword-12345"

persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      storageClass: "longhorn"
      size: 200Gi
    jobservice:
      jobLog:
        storageClass: "longhorn"
        size: 5Gi
    database:
      storageClass: "longhorn"
      size: 20Gi
    redis:
      storageClass: "longhorn"
      size: 5Gi
    trivy:
      storageClass: "longhorn"
      size: 10Gi

trivy:
  enabled: true

notary:
  enabled: false
EOF
```

Important notes:

- `expose.type: ingress` means Harbor is exposed using Kubernetes Ingress.
- `expose.ingress.className: nginx` connects the Ingress object to NGINX Ingress Controller.
- `expose.tls.enabled: true` enables HTTPS.
- `certSource: secret` tells Harbor to use an existing Kubernetes TLS secret.
- `externalURL` must match the real external address of Harbor.
- `proxy-body-size: "0"` avoids upload limits when pushing large image layers.
- `proxy-read-timeout` and `proxy-send-timeout` help with long push/pull operations.
- `persistence.enabled: true` is important because registry data must survive Pod restarts.

If `externalURL` is wrong, Docker login, token service, redirects, and UI links may behave incorrectly.

---

## 10. Install Harbor with Helm

Install or upgrade Harbor using `helm upgrade --install`:

```bash
helm upgrade --install harbor harbor/harbor \
  --namespace harbor \
  --version 1.19.1 \
  -f values-harbor.yaml
```

This command is useful because it works for both first installation and repeated updates.

Wait a few minutes, then check the deployment:

```bash
kubectl get pods -n harbor
kubectl get pvc -n harbor
kubectl get svc -n harbor
kubectl get ingress -n harbor
helm status harbor -n harbor
```

If Pods are `Pending`, check PVCs and StorageClass.

```bash
kubectl get pvc -n harbor
kubectl describe pvc -n harbor <PVC-NAME>
```

If Pods are crashing, check logs:

```bash
kubectl logs -n harbor deploy/harbor-core
kubectl logs -n harbor deploy/harbor-jobservice
kubectl describe pod -n harbor <POD-NAME>
```

---

## 11. Verify Ingress and UI Access

Check the Ingress:

```bash
kubectl get ingress -n harbor
kubectl describe ingress -n harbor
```

Test HTTPS response:

```bash
curl -Ik https://harbor.example.com
```

Open Harbor in a browser:

```text
https://harbor.example.com
```

Default username:

```text
admin
```

Password:

```text
ChangeThisPassword-12345
```

This is the value from `harborAdminPassword`. Change it for real use.

---

## 12. Create a Harbor Project

In the Harbor UI:

1. Log in as `admin`.
2. Go to **Projects**.
3. Create a new project named `devops-demo`.
4. Keep it private for this lab.
5. Later, create Robot Accounts for CI/CD instead of using admin credentials.

Why private?

A private project forces students to understand `docker login` and Kubernetes `imagePullSecret`.

---

## 13. Docker Login, Tag, Push, and Pull

From your local machine or CI runner:

```bash
docker login harbor.example.com
```

Pull a small test image:

```bash
docker pull nginx:alpine
```

Tag it for Harbor:

```bash
docker tag nginx:alpine harbor.example.com/devops-demo/nginx:alpine
```

Push it:

```bash
docker push harbor.example.com/devops-demo/nginx:alpine
```

Now check the Harbor UI. You should see a new repository under the `devops-demo` project.

Test pull:

```bash
docker rmi harbor.example.com/devops-demo/nginx:alpine || true
docker pull harbor.example.com/devops-demo/nginx:alpine
```

If Trivy is enabled, you can run or inspect a vulnerability scan in the Harbor UI.

---

## 14. Pull a Private Image from Kubernetes

Create a namespace for the demo app:

```bash
kubectl create namespace demo-app
```

Create an image pull secret in the same namespace:

```bash
kubectl -n demo-app create secret docker-registry harbor-regcred \
  --docker-server=harbor.example.com \
  --docker-username=admin \
  --docker-password='ChangeThisPassword-12345' \
  --docker-email=admin@example.com
```

Important:

> The `imagePullSecret` must exist in the same namespace as the workload that uses it.

Create a test Deployment:

```bash
cat > demo-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: harbor-nginx-demo
  namespace: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: harbor-nginx-demo
  template:
    metadata:
      labels:
        app: harbor-nginx-demo
    spec:
      imagePullSecrets:
        - name: harbor-regcred
      containers:
        - name: nginx
          image: harbor.example.com/devops-demo/nginx:alpine
          ports:
            - containerPort: 80
EOF
```

Apply it:

```bash
kubectl apply -f demo-deployment.yaml
kubectl get pods -n demo-app -w
```

If the Pod starts, the full path is working:

```text
Kubernetes -> worker node -> container runtime -> Harbor -> private image pull -> Pod starts
```

---

## 15. If the Certificate Is Public and Trusted

If Harbor uses a public trusted certificate, for example from Let's Encrypt, most clients trust it automatically:

- Browser
- Docker CLI
- curl
- CI runner base systems
- Kubernetes worker nodes

In this case, Kubernetes usually only needs the correct `imagePullSecret`.

If something fails, check:

- Image name
- Project name
- Tag
- Username/password or robot token
- Project permissions
- `externalURL`
- Ingress host

---

## 16. If the Certificate Is Private or Self-Signed

If Harbor uses a private CA or self-signed certificate, Docker and Kubernetes worker nodes may not trust it automatically.

You must distribute the CA certificate to:

- Developer machines
- CI runners
- All Kubernetes worker nodes

### Docker Runtime Trust

On a machine using Docker runtime:

```bash
sudo mkdir -p /etc/docker/certs.d/harbor.example.com
sudo cp ca.crt /etc/docker/certs.d/harbor.example.com/ca.crt
sudo systemctl restart docker
```

Then test:

```bash
docker login harbor.example.com
```

### containerd Runtime Trust

Most modern Kubernetes clusters use containerd.

On **each worker node**:

```bash
sudo mkdir -p /etc/containerd/certs.d/harbor.example.com
sudo cp ca.crt /etc/containerd/certs.d/harbor.example.com/ca.crt
```

Create `hosts.toml`:

```bash
sudo tee /etc/containerd/certs.d/harbor.example.com/hosts.toml > /dev/null <<'EOF'
server = "https://harbor.example.com"

[host."https://harbor.example.com"]
  capabilities = ["pull", "resolve", "push"]
  ca = "/etc/containerd/certs.d/harbor.example.com/ca.crt"
EOF
```

Restart containerd:

```bash
sudo systemctl restart containerd
```

Then recreate or restart the test Pod.

If you still see `x509: certificate signed by unknown authority`, check:

- The correct CA file was copied
- The certificate hostname matches `harbor.example.com`
- The file exists on every worker node
- containerd was restarted
- The Pod is scheduled on a node where the CA was installed

---

## 17. HTTP / Insecure Registry Mode: Lab Only

Harbor can be exposed without TLS, but this is not recommended for production.

Use this only for a short lab when you intentionally want to demonstrate insecure registry behavior.

Example HTTP values:

```yaml
expose:
  type: ingress
  tls:
    enabled: false
  ingress:
    className: nginx
    hosts:
      core: harbor.example.com
    annotations:
      nginx.ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/proxy-send-timeout: "600"

externalURL: http://harbor.example.com

harborAdminPassword: "ChangeThisPassword-12345"
```

Install with the HTTP values file:

```bash
helm upgrade --install harbor harbor/harbor \
  --namespace harbor \
  --version 1.19.1 \
  -f values-harbor-http-lab.yaml
```

### Docker Insecure Registry

On a Docker client:

```bash
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "insecure-registries": ["harbor.example.com"]
}
EOF

sudo systemctl restart docker
```

### containerd HTTP Registry

On each worker node:

```bash
sudo mkdir -p /etc/containerd/certs.d/harbor.example.com

sudo tee /etc/containerd/certs.d/harbor.example.com/hosts.toml > /dev/null <<'EOF'
server = "http://harbor.example.com"

[host."http://harbor.example.com"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF

sudo systemctl restart containerd
```

Again:

> HTTP/insecure registry is for labs only. In production, use HTTPS and proper certificate verification.

---

## 18. Robot Accounts for CI/CD

For a quick classroom demo, you may use the `admin` user. In real environments, do not put admin credentials in CI/CD pipelines.

Use Harbor Robot Accounts.

In the Harbor UI:

1. Open the `devops-demo` project.
2. Go to **Robot Accounts**.
3. Create a robot account.
4. Give it the minimum required permissions, such as push/pull for that project.
5. Copy the generated token.
6. Store it in your CI/CD secret manager.

Example login:

```bash
docker login harbor.example.com \
  -u 'robot$devops-demo+ci' \
  -p '<ROBOT_TOKEN>'
```

Example build and push:

```bash
docker build -t harbor.example.com/devops-demo/app:1.0 .
docker push harbor.example.com/devops-demo/app:1.0
```

Recommended model:

| Use Case | Credential Type |
|---|---|
| Human admin operations | Human admin account |
| CI build and push | Robot account with push/pull on one project |
| Kubernetes production pull | Pull-only robot account or limited user |
| Replication | Dedicated scoped robot/service credential |

---

## 19. Attach Pull Secret to the Default ServiceAccount

Instead of adding `imagePullSecrets` to every Deployment, you can patch the default ServiceAccount in a namespace.

```bash
kubectl -n demo-app patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "harbor-regcred"}]}'
```

Verify:

```bash
kubectl -n demo-app get serviceaccount default -o yaml
```

This is useful when most workloads in a namespace pull private images from Harbor.

---

## 20. Upgrade Harbor or Change Values

After changing `values-harbor.yaml`, apply the change with Helm:

```bash
helm upgrade harbor harbor/harbor \
  --namespace harbor \
  --version 1.19.1 \
  -f values-harbor.yaml
```

Check release history:

```bash
helm history harbor -n harbor
```

Rollback if needed:

```bash
helm rollback harbor <REVISION> -n harbor
```

Before upgrading Harbor versions, review official release notes and backup important data.

At minimum, think about backing up:

- Database
- Registry storage
- Kubernetes secrets
- Helm values
- TLS material

---

## 21. Production Notes

A working installation is not automatically production-ready.

For production, consider:

- External PostgreSQL or a properly backed-up database
- External Redis or a reliable Redis deployment
- Durable registry storage
- Object storage for larger deployments
- Longhorn backup/snapshot policy if using Longhorn PVCs
- Secure password and secret handling
- Monitoring and alerting
- TLS certificate renewal
- Retention policies
- Garbage collection
- Quotas
- Audit log review
- Upgrade testing
- Restore testing

If using Longhorn, remember that Longhorn provides block-level replication for PVCs. This can be useful, but registry data still needs a backup and recovery strategy.

For larger registry workloads, object storage such as S3-compatible storage or MinIO is often a cleaner model for registry blobs.

---

## 22. Troubleshooting by Layer

Do not reinstall Harbor blindly. Diagnose by layer.

| Symptom | What to Check |
|---|---|
| Browser does not open Harbor | DNS, Ingress IP, Ingress object, firewall, NGINX Ingress service |
| `curl` shows certificate error | Certificate chain, hostname, TLS secret, trust store |
| `docker login` says unauthorized | Username, password, robot token, project permission, `externalURL` |
| `docker push` fails with 413 | `nginx.ingress.kubernetes.io/proxy-body-size` annotation |
| Pod is in `ImagePullBackOff` | Image name, tag, imagePullSecret, project access, node certificate trust |
| PVC is Pending | StorageClass, provisioner, capacity, Longhorn or storage backend |
| Redirect or token endpoint is wrong | `externalURL` and Ingress host mismatch |
| `x509: certificate signed by unknown authority` | CA not trusted on client or worker node |
| `manifest unknown` | Wrong image name, repository, or tag |
| `connection refused` | DNS, Ingress, service, firewall, or Harbor Pods |

Useful commands:

```bash
kubectl get pods -n harbor
kubectl get pvc -n harbor
kubectl get svc -n harbor
kubectl get ingress -n harbor
kubectl get events -n harbor --sort-by=.lastTimestamp
helm status harbor -n harbor
helm history harbor -n harbor
```

For app image pull issues:

```bash
kubectl describe pod -n demo-app <POD-NAME>
kubectl get events -n demo-app --sort-by=.lastTimestamp
```

Harbor logs:

```bash
kubectl logs -n harbor deploy/harbor-core
kubectl logs -n harbor deploy/harbor-jobservice
kubectl logs -n harbor deploy/harbor-registry
```

Ingress checks:

```bash
kubectl describe ingress -n harbor
curl -Ik https://harbor.example.com
```

---

## 23. Cleanup for Lab Repetition

To uninstall the Helm release:

```bash
helm uninstall harbor -n harbor
```

Check remaining PVCs:

```bash
kubectl get pvc -n harbor
```

For a full lab reset, delete PVCs and namespace:

```bash
kubectl delete pvc --all -n harbor
kubectl delete ns harbor
```

Warning:

> In production, never delete Harbor PVCs without a verified backup. Deleting registry PVCs may destroy stored images.

---

## 24. Final Installation Checklist

Before considering the lab successful, verify:

- `harbor.example.com` resolves to the correct Ingress IP
- IngressClass `nginx` exists
- TLS secret `harbor-tls` exists in namespace `harbor`
- `externalURL` is exactly `https://harbor.example.com`
- StorageClass is correct
- PVCs are `Bound`
- Harbor Pods are running
- Harbor Ingress exists
- Harbor UI opens in browser
- Admin login works
- Project `devops-demo` exists
- `docker login` works
- `docker push` works
- `docker pull` works
- Private image pull from Kubernetes works with `imagePullSecret`
- If using private/self-signed CA, worker nodes trust the CA
- If using HTTP lab mode, Docker/containerd insecure registry settings are configured

---

## 25. Full Command Flow Summary

For quick reference, here is the main HTTPS flow.

```bash
# Check cluster
kubectl cluster-info
kubectl get nodes -o wide
helm version
kubectl get ingressclass
kubectl get svc -n ingress-nginx

# Add Harbor Helm repository
helm repo add harbor https://helm.goharbor.io
helm repo update
helm search repo harbor/harbor --versions | head -10

# Create namespace
kubectl create namespace harbor

# Create TLS secret
kubectl -n harbor create secret tls harbor-tls \
  --cert=fullchain.pem \
  --key=privkey.pem

# Install Harbor
helm upgrade --install harbor harbor/harbor \
  --namespace harbor \
  --version 1.19.1 \
  -f values-harbor.yaml

# Verify Harbor
kubectl get pods -n harbor
kubectl get pvc -n harbor
kubectl get svc -n harbor
kubectl get ingress -n harbor
helm status harbor -n harbor
curl -Ik https://harbor.example.com

# Docker test
docker login harbor.example.com
docker pull nginx:alpine
docker tag nginx:alpine harbor.example.com/devops-demo/nginx:alpine
docker push harbor.example.com/devops-demo/nginx:alpine
docker pull harbor.example.com/devops-demo/nginx:alpine

# Kubernetes pull test
kubectl create namespace demo-app
kubectl -n demo-app create secret docker-registry harbor-regcred \
  --docker-server=harbor.example.com \
  --docker-username=admin \
  --docker-password='ChangeThisPassword-12345' \
  --docker-email=admin@example.com
kubectl apply -f demo-deployment.yaml
kubectl get pods -n demo-app -w
```

---

## 26. Official References

- Harbor official website: `https://goharbor.io/`
- Harbor documentation: `https://goharbor.io/docs/`
- Harbor Helm chart repository: `https://github.com/goharbor/harbor-helm`
- Official Harbor Helm repository: `https://helm.goharbor.io`
- Harbor GitHub releases: `https://github.com/goharbor/harbor/releases`
- Harbor Helm releases: `https://github.com/goharbor/harbor-helm/releases`

---

## Final Teaching Summary

In this lab, we did not only install Harbor. We built the full registry workflow.

We exposed Harbor through NGINX Ingress, enabled TLS, configured `externalURL`, pushed an image to Harbor, and pulled a private image from Kubernetes using `imagePullSecret`.

The most important lesson is this:

> Kubernetes needs two things to pull a private image successfully: correct credentials and correct certificate trust.

If Harbor uses a public trusted certificate, the workflow is clean. If Harbor uses a private or self-signed certificate, the CA must be trusted by clients and all worker nodes. If TLS is disabled, we enter insecure registry mode, which should be used only for short lab scenarios.

From here, Harbor can be connected to CI/CD using Robot Accounts, proper image tags, vulnerability scanning, and controlled promotion workflows.
