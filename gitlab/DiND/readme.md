# GitLab Runner + Docker-in-Docker (DinD)

This guide shows how to run **GitLab Runner inside Docker** and build images using a **sidecar Docker daemon** (`docker:dind`). Your job’s `docker` CLI connects to the sidecar over TCP, not to the host socket.

```
[Runner container] --/var/run/docker.sock--> [Host dockerd]   (only so Runner can create job/service containers)
[Job container]    --TCP 2375/2376---------> [Sidecar docker:dind (dockerd)]
```

## Why DinD
- **Isolation:** each job uses its own daemon (no host socket exposure to jobs).
- **Tradeoff:** heavier and typically slower than DooD; needs `privileged`.

---

## Prerequisites
- Docker is installed on the host where Runner runs.
- A **registration token** from your GitLab instance.

> Pin versions (e.g., `docker:24`) rather than using `latest`.

---

## 1) Runner `docker-compose.yml`
Mount the host Docker socket **into the Runner container** so the Runner can create job and service containers on the host.

```yaml
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner-dind
    restart: unless-stopped
    volumes:
      - ./config:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock
```

```bash
docker compose up -d
```

---

## 2) Register the Runner
Pass boolean flags with `=true` to avoid warnings.

```bash
docker exec -it gitlab-runner-dind gitlab-runner register   --non-interactive   --url "https://gitlab.your-domain.com/"   --registration-token "YOUR_REG_TOKEN"   --executor "docker"   --description "Runner DinD"   --tag-list "docker-dind"   --docker-image "docker:24"   --docker-privileged=true   --docker-volumes "/cache"   --docker-pull-policy "if-not-present"
```

**Minimal `config.toml` (saved under `./config/config.toml`):**
```toml
[[runners]]
  name = "Runner DinD"
  url = "https://gitlab.your-domain.com/"
  token = "REPLACED_BY_AUTH_TOKEN"
  executor = "docker"

  [runners.docker]
    image = "docker:24"
    privileged = true
    pull_policy = "if-not-present"
    volumes = ["/cache"]
```

---

## 3) Example `.gitlab-ci.yml`
Simple version—TLS disabled for easier testing.

```yaml
build-job:
  image: docker:24                # or your mirror: docker.arvancloud.ir/docker:24
  services:
    - docker:24-dind              # or mirror: docker.arvancloud.ir/docker:24-dind
  stage: build
  tags: [ "docker-dind" ]
  variables:
    DOCKER_TLS_CERTDIR: ""        # disable TLS for simplicity
    DOCKER_HOST: "tcp://docker:2375"
    DOCKER_BUILDKIT: "1"
  script:
    - docker info
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
    - docker build -t "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA" .
    - docker push "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA"
  only:
    - main
```

### Optional: TLS-enabled DinD
```yaml
variables:
  DOCKER_TLS_CERTDIR: "/certs"   # default in docker:dind
# Usually you can omit DOCKER_HOST; docker CLI auto-detects tcp://docker:2376 with TLS
services:
  - docker:24-dind
```

---

## 4) Caching Layers in DinD
By default, the sidecar daemon’s `/var/lib/docker` is ephemeral. To persist cache:

- **Persist sidecar storage via Runner volumes** (applies to services too):
```toml
[runners.docker]
  volumes = [
    "/cache",
    "/opt/gitlab-runner/dind-cache:/var/lib/docker"
  ]
```

- **BuildKit registry cache** (recommended):
```bash
docker build   --build-arg BUILDKIT_INLINE_CACHE=1   --cache-to   type=registry,ref=$CI_REGISTRY_IMAGE:buildcache,mode=max   --cache-from type=registry,ref=$CI_REGISTRY_IMAGE:buildcache   -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .
```

---

## 5) Troubleshooting

- **During Preparing:** `Cannot connect to the Docker daemon at unix:///var/run/docker.sock`  
  → You didn’t mount the host socket into the Runner container. Add `- /var/run/docker.sock:/var/run/docker.sock` in compose and restart the Runner.

- **Job can’t reach daemon:** ensure in DinD jobs you set `DOCKER_HOST=tcp://docker:2375` (or use TLS). Print `docker info` inside the job.

- **Tags mismatch:** the job’s tag (`docker-dind`) must match the Runner’s tag list.

```bash
docker compose restart gitlab-runner
docker exec -it gitlab-runner-dind ls -l /var/run/docker.sock
```

---

## Security Notes
- DinD avoids exposing the host socket to jobs → better isolation.
- Still pin images (`docker:24`, `gitlab/gitlab-runner:<version>`) and use dedicated runners per team if possible.
