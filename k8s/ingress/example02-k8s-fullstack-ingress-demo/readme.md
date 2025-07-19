# Kubernetes React + Node.js App with NGINX Ingress

This project demonstrates a real-world, production-style Kubernetes setup using:

- 🔷 React frontend (built with Vite)
- 🟢 Node.js backend (Express API)
- 🌐 NGINX Ingress with path-based routing (`/` for frontend, `/api` for backend)
- 🐳 Docker images and Kubernetes manifests ready for deployment

---

## 🗂 Project Structure

```
.
├── backend/                # Node.js Express API
├── frontend/               # React frontend (created via Docker container)
├── manifests/              # Kubernetes YAMLs: Deployment, Service, Ingress
└── README.md
```

---

## 🐳 Dockerized Frontend (Vite)

Since local Node.js was outdated, the frontend was created using Docker:

```bash
docker run -it --rm -v ${PWD}:/app -w /app node:18-alpine sh -c "npm create vite@latest frontend -- --template react"
```

This command creates the frontend app, installs dependencies, and builds the project inside the container.

---

## 📦 Backend Setup

```bash
cd backend
npm install
docker build -t your-registry.com:8443/node-api:latest .
```

---

## 🚢 Docker Image Builds

Tag and push both images to your private registry:
```bash
# Frontend
docker build -t registry.sananetco.com:8443/react-app:latest ./frontend
docker push registry.sananetco.com:8443/react-app:latest

# Backend
docker build -t registry.sananetco.com:8443/node-api:latest ./backend
docker push registry.sananetco.com:8443/node-api:latest
```

---

## 🔐 Create Image Pull Secret in Kubernetes

```bash
kubectl create secret docker-registry regcred \
  --docker-server=registry.sananetco.com:8443 \
  --docker-username=admin \
  --docker-password='123@qwe' \
  --docker-email=devops@sananetco.com \
  -n prod-apps
```

---

## 🚀 Kubernetes Deployment

Apply manifests:

```bash
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/frontend-deployment.yaml
kubectl apply -f manifests/backend-deployment.yaml
kubectl apply -f manifests/ingress.yaml
```

---

## 🌐 Access

After configuring DNS or using `/etc/hosts`, access:

- `http://myapp.example.com/` → React frontend
- `http://myapp.example.com/api` → Node.js API

Use `nip.io` if DNS isn't available:

```yaml
host: myapp.127.0.0.1.nip.io
```

---

## 🔒 TLS (Optional)

If using cert-manager:

```yaml
tls:
  - hosts:
      - myapp.example.com
    secretName: myapp-tls
```

---

## 📘 License

MIT – feel free to use and modify for your own Kubernetes full-stack setups.

---

