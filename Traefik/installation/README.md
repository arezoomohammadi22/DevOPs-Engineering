# README.md: Installing Traefik on Kubernetes with Helm

This guide explains how to install Traefik using Helm on Kubernetes and details the meaning of all the `--set` options used in the installation command.

---

## Helm Install Command

```bash
helm install traefik traefik/traefik \
  -n traefik --create-namespace \
  --set service.type=NodePort \
  --set ports.web.port=8000 \
  --set ports.web.exposedPort=80 \
  --set ports.web.nodePort=30080 \
  --set ports.websecure.port=8443 \
  --set ports.websecure.exposedPort=443 \
  --set ports.websecure.nodePort=30443 \
  --set ports.traefik.port=8080 \
  --set ports.traefik.exposedPort=8080 \
  --set ports.traefik.nodePort=30090 \
  --set ports.traefik.expose.default=true \
  --set api.dashboard=true \
  --set ingressRoute.dashboard.enabled=true
```

---

## Explanation of Options

### 1️⃣ Namespace
- `-n traefik`: Install Traefik in the `traefik` namespace.
- `--create-namespace`: Creates the namespace if it does not exist.

### 2️⃣ Service Type
- `--set service.type=NodePort`: The type of Kubernetes service Traefik will create. `NodePort` exposes the service on each Node, making it accessible externally.

### 3️⃣ HTTP (Web) Ports
- `--set ports.web.port=8000`: Internal HTTP port inside the Traefik Pod.
- `--set ports.web.exposedPort=80`: Suggested external port for HTTP access (standard port 80).
- `--set ports.web.nodePort=30080`: Actual Node port for HTTP when using NodePort service type.

### 4️⃣ HTTPS (WebSecure) Ports
- `--set ports.websecure.port=8443`: Internal HTTPS port inside the Traefik Pod.
- `--set ports.websecure.exposedPort=443`: Suggested external port for HTTPS access (standard port 443).
- `--set ports.websecure.nodePort=30443`: Actual Node port for HTTPS when using NodePort service type.

### 5️⃣ Traefik Dashboard / API Ports
- `--set ports.traefik.port=8080`: Internal Dashboard/API port inside the Pod.
- `--set ports.traefik.exposedPort=8080`: Suggested external port for Dashboard/API access.
- `--set ports.traefik.nodePort=30090`: Actual Node port for Dashboard/API when using NodePort.
- `--set ports.traefik.expose.default=true`: Ensures the Dashboard/API is exposed by default.

### 6️⃣ Enable Dashboard
- `--set api.dashboard=true`: Enables the Traefik Dashboard.
- `--set ingressRoute.dashboard.enabled=true`: Enables a dedicated IngressRoute for the Dashboard to make it accessible via Traefik.

---

💡 Notes:

- NodePorts (`30080`, `30443`, `30090`) allow direct access to Nodes from outside.
- ExposedPorts (`80`, `443`, `8080`) are suggested ports for standard external access via LoadBalancer.
- To access Traefik externally without NodePort, change the service type to `LoadBalancer`.
- This setup includes HTTP, HTTPS, and Traefik Dashboard and supports IngressRoute and Middlewares.

