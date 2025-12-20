# GitLab CI/CD – Docker Build & Kubernetes Deploy (No Helm)

This repository demonstrates a **complete, production-ready GitLab CI/CD pipeline**
that builds a Docker image and deploys it to Kubernetes **without Helm**.

It uses:
- Kubernetes GitLab Runner (`k8s` tag)
- Docker-in-Docker (DinD)
- GitLab Container Registry
- GitLab Kubernetes Agent
- GitLab dotenv artifacts for image handoff

---

## 📌 Pipeline Flow

```
Build Image  →  Push to Registry  →  Deploy to Kubernetes
```

---

## 🗂 Repository Structure

```
.
├── Dockerfile
├── .gitlab-ci.yml
├── deployment.yaml
└── README.md
```

---

## ⚙️ Prerequisites

### 1. GitLab Runner
- Installed on Kubernetes
- Runner tag: `k8s`
- **Privileged mode enabled** (required for DinD)

### 2. GitLab Kubernetes Agent
- Agent project: `devops-cource/devtest01`
- Agent name: `k8s-connection`
- Agent status: **Connected**

### 3. Kubernetes Deployment
- Namespace: `default`
- Deployment name: `nginx-deployment`
- Container name: `nginx`

### 4. Registry Access
- Image registry credentials available in GitLab CI variables:
  - `CI_REGISTRY`
  - `CI_REGISTRY_USER`
  - `CI_REGISTRY_PASSWORD`

---

## 🚀 GitLab CI/CD Configuration

### 📄 `.gitlab-ci.yml`

```yaml
stages:
  - build
  - deploy

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

    # Login to GitLab Container Registry
    - echo "$CI_REGISTRY_PASSWORD" | docker login "$CI_REGISTRY" -u "$CI_REGISTRY_USER" --password-stdin

    # Build & push Docker image
    - docker build -t "$CI_REGISTRY_IMAGE:$IMAGE_TAG" -t "$CI_REGISTRY_IMAGE:latest" .
    - docker push "$CI_REGISTRY_IMAGE:$IMAGE_TAG"
    - docker push "$CI_REGISTRY_IMAGE:latest"

    # Export image info as dotenv artifact
    - echo "IMAGE_TAG=$IMAGE_TAG" > build.env
    - echo "IMAGE_NAME=$CI_REGISTRY_IMAGE" >> build.env
    - echo "IMAGE_FULL=$CI_REGISTRY_IMAGE:$IMAGE_TAG" >> build.env

  artifacts:
    reports:
      dotenv: build.env
    expire_in: 1 day

deploy:
  stage: deploy
  image: docker.arvancloud.ir/dtzar/helm-kubectl:latest
  tags:
    - k8s
  needs:
    - job: build-and-push
      artifacts: true
  script:
    - echo "Deploying image: $IMAGE_FULL"

    # Use GitLab Kubernetes Agent context
    - kubectl config get-contexts
    - kubectl config use-context devops-cource/devtest01:k8s-connection

    # Update image on existing Deployment
    - kubectl -n default set image deployment/nginx-deployment nginx="$IMAGE_FULL"
    - kubectl -n default rollout status deployment/nginx-deployment

  environment:
    name: production
    url: https://app.sananetco.com
    kubernetes:
      agent: devops-cource/devtest01:k8s-connection
```

---

## 🐳 Dockerfile Example

```dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html
```

---

## ☸️ Kubernetes Deployment

### 📄 `deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      imagePullSecrets:
        - name: registry-sananetco
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

> ⚠️ The image is dynamically updated by CI using:
>
> `kubectl set image deployment/nginx-deployment nginx=$IMAGE_FULL`

---

## 📦 Artifacts (dotenv)

The build job produces a dotenv artifact:

```env
IMAGE_TAG=73fee528
IMAGE_NAME=registry.gitlab.com/devops-cource/devtest03
IMAGE_FULL=registry.gitlab.com/devops-cource/devtest03:73fee528
```

These variables are automatically injected into the deploy job.

---

## 🌍 Environments

After deployment:
- Go to **CI/CD → Environments**
- Environment: `production`
- URL: https://app.sananetco.com

This URL is informational and does not create ingress or DNS.

---

## 🔍 Verification Commands

```bash
kubectl get deployment nginx-deployment -n default
kubectl rollout status deployment nginx-deployment -n default
kubectl rollout history deployment nginx-deployment -n default
```

---

## 🧠 Best Practices

- Use **Deploy Tokens** instead of Personal Access Tokens
- Keep image tags immutable (`CI_COMMIT_SHA`)
- Add rollback job if needed:
  ```bash
  kubectl rollout undo deployment/nginx-deployment
  ```

---

## ✅ Summary

✔ No Helm  
✔ No static kubeconfig  
✔ Secure Kubernetes access via GitLab Agent  
✔ Clean artifact-based image passing  
✔ Production-ready CI/CD pipeline
