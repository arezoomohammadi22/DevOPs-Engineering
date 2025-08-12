# GitLab Runner + Docker-out-of-Docker (DooD)

This guide shows how to run **GitLab Runner inside Docker** and build images by sharing the **host’s Docker daemon** with job containers via the Docker socket.

```
[Runner container] --/var/run/docker.sock--> [Host dockerd]
[Job container]    --/var/run/docker.sock--> [Host dockerd]
```

## Why DooD
- **Fast** builds, warm image cache from the host daemon.
- **Risk:** mounting `/var/run/docker.sock` gives jobs root-equivalent power on the host. Use for **trusted repos** only.

---

## 1) Runner `docker-compose.yml`

```yaml
services:
  gitlab-runner:
    image: gitlab/gitlab-runner:latest
    container_name: gitlab-runner-dood
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

```bash
docker exec -it gitlab-runner-dood gitlab-runner register   --non-interactive   --url "https://gitlab.your-domain.com/"   --registration-token "YOUR_REG_TOKEN"   --executor "docker"   --description "Runner DooD"   --tag-list "docker-dood"   --docker-image "docker:24"   --docker-volumes "/var/run/docker.sock:/var/run/docker.sock"   --docker-volumes "/cache"   --docker-pull-policy "if-not-present"
```

**Minimal `config.toml`:**
```toml
[[runners]]
  name = "Runner DooD"
  url = "https://gitlab.your-domain.com/"
  token = "REPLACED_BY_AUTH_TOKEN"
  executor = "docker"

  [runners.docker]
    image = "docker:24"
    privileged = false
    pull_policy = "if-not-present"
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock",
      "/cache"
    ]
```

---

## 3) Example `.gitlab-ci.yml` (no `docker:dind` service)

```yaml
build-job:
  image: docker:24                            # or mirror: docker.arvancloud.ir/docker:24
  stage: build
  tags: [ "docker-dood" ]
  variables:
    DOCKER_BUILDKIT: "1"
  script:
    - docker info                             # talks to host dockerd via socket
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
    - docker build -t "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA" .
    - docker push "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA"
  only:
    - main
```

---

## 4) Optimization
- Enable BuildKit (`DOCKER_BUILDKIT=1`), use multi-stage Dockerfiles.
- Cross-arch: `docker buildx create --use` (still uses host daemon).
- Periodic cleanup on the host (use with care):
```bash
docker system prune -af --volumes
```

---

## 5) Troubleshooting
- `Cannot connect to the Docker daemon … unix:///var/run/docker.sock`  
  → Ensure the socket is mounted both into the Runner and into each job container via Runner config.
- Ensure job tags match Runner tags.
- Print `docker info` inside the job to verify connectivity.

---

## Security Notes
- Sharing the host socket gives jobs full control of the host daemon. Prefer DinD or daemonless builders for multi-tenant or security-sensitive setups.
