# GitLab Runner on Kubernetes (Kubernetes Executor + Docker-in-Docker)

This repository documents a **production-ready setup** for installing **GitLab Runner** on a Kubernetes cluster using the **Kubernetes executor**, where:

- ✅ **Every GitLab CI job runs in its own Kubernetes Pod**
- ✅ Docker commands (`docker build`, `docker push`) are supported using **Docker-in-Docker (DinD)**
- ✅ Installation is managed via **Helm**

This setup is ideal for CI pipelines that need **isolated build environments** and **container image builds**.

---

## Architecture Overview

- **GitLab Runner** is installed in the `gitlab-runner` namespace
- Runner executor: **Kubernetes**
- Each CI job:
  - Runs in a **dedicated Pod**
  - Uses `docker:27` as the main container (Docker CLI)
  - Uses `docker:27-dind` as a **sidecar service** (Docker daemon)
- Runner operates in **privileged mode** to allow DinD

```
GitLab CI Job
   └── Kubernetes Pod
       ├── build container (docker:27)
       └── service container (docker:27-dind)
```

---

## Prerequisites

Before you begin, make sure you have:

- A running Kubernetes cluster
- `kubectl` configured and connected to the cluster
- `helm` v3 installed
- Access to your GitLab instance
- A **GitLab Runner registration token**

---

## Add GitLab Helm Repository

```bash
helm repo add gitlab https://charts.gitlab.io
helm repo update
```

---

## Install / Upgrade GitLab Runner

The following command installs (or upgrades) GitLab Runner using the **Kubernetes executor**.

```bash
helm upgrade --install gitlab-runner gitlab/gitlab-runner \
  -n gitlab-runner --create-namespace \
  --set gitlabUrl=https://gitlab.sananetco.com \
  --set runnerRegistrationToken=Eaw8FLXAANVERXmqkExL \
  --set rbac.create=true \
  --set serviceAccount.create=true \
  --set runners.executor=kubernetes \
  --set runners.tags="k8s" \
  --set runners.privileged=true \
  --set runners.config='
[[runners]]
  name = "k8s-job-pods"
  executor = "kubernetes"
  [runners.kubernetes]
    namespace = "gitlab-runner"
    privileged = true
'
```

### What this configuration does

- Registers the runner to `https://gitlab.sananetco.com`
- Enables RBAC and a dedicated ServiceAccount
- Uses **Kubernetes executor** (one Pod per job)
- Enables **privileged mode** (required for DinD)
- Assigns the runner tag: `k8s`

---

## Verify Installation

```bash
kubectl get pods -n gitlab-runner
```

Check runner logs:

```bash
kubectl logs -n gitlab-runner deploy/gitlab-runner
```

In GitLab UI:

```
Project / Admin → CI/CD → Runners
```

You should see:

```
k8s-job-pods (online)
```

---

## GitLab CI Pipeline Example

This `.gitlab-ci.yml` demonstrates a **build stage** that runs Docker commands inside a Kubernetes Pod.

```yaml
stages:
  - build

build-image:
  stage: build
  tags:
    - k8s
  image: docker:27
  services:
    - name: docker:27-dind
      command: ["--tls=false"]
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
  script:
    - docker info
    - docker build -t myapp:latest .
```

### How this works

- `image: docker:27` → Docker CLI container
- `docker:27-dind` → Sidecar Docker daemon
- `DOCKER_HOST` → Connects Docker CLI to DinD service
- Each job runs in a **fresh Kubernetes Pod**

---

## Sample Dockerfile

Below is a minimal example Dockerfile that works with the pipeline above:

```Dockerfile
FROM alpine:3.20

RUN apk add --no-cache curl

WORKDIR /app

CMD ["echo", "Hello from Docker build inside GitLab CI on Kubernetes!"]
```

---

## Security Considerations

⚠️ **Important**: This setup uses:

- Privileged Pods
- Docker-in-Docker

This is powerful but **not recommended for multi-tenant or highly restricted clusters**.

### Safer alternatives

- **Kaniko** (daemonless image builds)
- **BuildKit (rootless)**
- Separate runners for `build` and `deploy` stages

---

## Troubleshooting

### Runner not picking jobs

- Ensure job tags match runner tags (`k8s`)
- Check runner status in GitLab UI

### Docker daemon not reachable

- Ensure `privileged=true`
- Verify `docker:dind` service is running in the job Pod

```bash
kubectl describe pod <job-pod> -n gitlab-runner
```

---

## Summary

- ✔ GitLab Runner installed via Helm
- ✔ Kubernetes executor (one Pod per job)
- ✔ Docker builds supported with DinD
- ✔ Clean, scalable CI architecture

