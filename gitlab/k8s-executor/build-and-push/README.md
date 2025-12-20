# GitLab Runner on Kubernetes (Kubernetes Executor) + HostAliases + Build & Push to GitLab Registry

This repository documents a working setup for **GitLab Runner installed on Kubernetes** using the **Kubernetes executor**, where:

- ✅ **Each GitLab CI job runs in its own Kubernetes Pod**
- ✅ Docker commands (`docker build`, `docker push`) work via **Docker-in-Docker (DinD)**
- ✅ Private DNS override for the registry is handled correctly using **Kubernetes `hostAliases`**
  - Example: `registry.sananetco.com -> 172.30.10.7`
- ✅ Builds are pushed to **GitLab Container Registry** using GitLab predefined CI variables

---

## Why `hostAliases` (and not `extra_hosts`)?

With **Kubernetes executor**, GitLab CI does **not** support `extra_hosts` in `.gitlab-ci.yml` (that key is for Docker executor).  
To inject `/etc/hosts` entries into job Pods on Kubernetes, the supported approach is:

✅ **Define `[[runners.kubernetes.host_aliases]]` in GitLab Runner config**.

---

## Prerequisites

- Kubernetes cluster + `kubectl` access
- Helm v3 installed
- Access to your GitLab instance: `https://gitlab.sananetco.com`
- GitLab Runner **registration token** (used in Helm install)

---

## 1) Add GitLab Helm Repository

```bash
helm repo add gitlab https://charts.gitlab.io
helm repo update
```

---

## 2) Install / Upgrade GitLab Runner (Kubernetes Executor + HostAliases)

This command installs GitLab Runner into the `gitlab-runner` namespace, enables RBAC + ServiceAccount, and configures:

- Executor: `kubernetes`
- Tag: `k8s`
- Privileged: `true` (required for DinD)
- HostAliases: `registry.sananetco.com -> 172.30.10.7`

```bash
helm upgrade --install gitlab-runner gitlab/gitlab-runner \
  -n gitlab-runner --create-namespace \
  --set gitlabUrl=https://gitlab.sananetco.com \
  --set runnerRegistrationToken=token \
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

    [[runners.kubernetes.host_aliases]]
      ip = "172.30.10.7"
      hostnames = ["registry.sananetco.com"]
'
```

> Tip: If you later add multiple host mappings, just add more `[[runners.kubernetes.host_aliases]]` blocks.

---

## 3) Verify Runner Installation

### Check the runner Pod
```bash
kubectl get pods -n gitlab-runner
```

### Check logs
```bash
kubectl logs -n gitlab-runner deploy/gitlab-runner
```

In GitLab UI:
- Go to **Project → Settings → CI/CD → Runners**
- Confirm runner is **online** and has tag `k8s`

---

## 4) CI Pipeline: Build & Push to GitLab Container Registry

Create `.gitlab-ci.yml` in your repo:

```yaml
stages:
  - build

build-and-push:
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
    IMAGE_TAG: "$CI_COMMIT_SHORT_SHA"
  script:
    - docker info
    - cat /etc/hosts

    - echo "$CI_REGISTRY_PASSWORD" | docker login "$CI_REGISTRY" -u "$CI_REGISTRY_USER" --password-stdin
    - docker build -t "$CI_REGISTRY_IMAGE:$IMAGE_TAG" -t "$CI_REGISTRY_IMAGE:latest" .
    - docker push "$CI_REGISTRY_IMAGE:$IMAGE_TAG"
    - docker push "$CI_REGISTRY_IMAGE:latest"
```

### What gets pushed?

GitLab provides these variables automatically:

- `CI_REGISTRY` (registry hostname)
- `CI_REGISTRY_IMAGE` (your project image path)
- `CI_REGISTRY_USER`
- `CI_REGISTRY_PASSWORD`

So your pushed images are typically:

- `$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA`
- `$CI_REGISTRY_IMAGE:latest`

---

## 5) Confirm HostAliases Worked

Your pipeline prints `/etc/hosts`:

```bash
cat /etc/hosts
```

You should see a line like:

```
172.30.10.7 registry.sananetco.com
```

This ensures the registry hostname resolves to the **private IP** from inside the job Pod.

---

## 6) Sample Dockerfile

Add a simple `Dockerfile` for testing:

```Dockerfile
FROM alpine:3.20

RUN apk add --no-cache curl

WORKDIR /app

CMD ["echo", "Hello from GitLab CI build inside Kubernetes Pod!"]
```

---

## Troubleshooting

### A) CI job not picked up by runner
- Ensure job tag matches runner tag: `k8s`
- Confirm runner is online in GitLab UI
- Check runner logs:
  ```bash
  kubectl logs -n gitlab-runner deploy/gitlab-runner
  ```

### B) Docker build fails / DinD issues
- Runner must be privileged (`--set runners.privileged=true`)
- Job uses `docker:27` + service `docker:27-dind`
- `DOCKER_HOST` must be set to `tcp://docker:2375`
- `DOCKER_TLS_CERTDIR` must be empty (since DinD is started with `--tls=false`)

### C) Registry DNS still resolves to public IP
- Confirm `host_aliases` is in the runner config (Helm command above)
- Confirm `/etc/hosts` output inside the pipeline contains your mapping
- If your registry uses TLS with an internal CA, you may also need to trust that CA inside the job image (separate step)

---

## Notes on Security

This approach uses **privileged Pods** + **DinD**, which is common for internal CI clusters but can be risky in multi-tenant environments.

If you later want a safer build method without privileged mode, consider:
- Kaniko
- Rootless BuildKit

---

## Summary

- ✔ GitLab Runner installed with **Kubernetes executor**
- ✔ **One Pod per job**
- ✔ Registry hostname forced to private IP via **hostAliases**
- ✔ Build and push to GitLab registry with predefined CI variables
- ✔ Fully reproducible with Helm + `.gitlab-ci.yml`
