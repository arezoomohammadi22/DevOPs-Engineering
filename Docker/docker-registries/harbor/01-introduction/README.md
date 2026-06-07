
# Harbor Registry for Kubernetes and DevOps

This README is a teaching-ready classroom script for the **conceptual part** of Harbor Registry.
It is written for students and can be read directly during a DevOps/Kubernetes class before the practical Helm installation.

The goal is not to memorize commands. The goal is to understand why a registry matters, why Harbor is more than a simple Docker Registry, and how Harbor becomes part of the software delivery and supply-chain workflow.

---

## Session Outline

1. Why a registry matters in DevOps and Kubernetes
2. Basic terms: Registry, Repository, Image, Tag, Layer, Artifact
3. What Harbor is and why it is not just a simple Docker Registry
4. Harbor in a real CI/CD pipeline
5. Harbor compared with Docker Registry, GitLab Container Registry, and Nexus Repository
6. Harbor internal components and Push/Pull request flow
7. Important Harbor features: RBAC, Robot Accounts, Vulnerability Scanning, Signing, Replication, Proxy Cache, Retention, Quota, Audit
8. The right mindset before installing Harbor on Kubernetes with Helm
9. Common implementation mistakes
10. Production-readiness checklist

---

## 1. Why Do We Need a Registry?

Before we talk about Harbor, we should ask a simple question:

> When we containerize an application, where does the final output go?

In Docker and Kubernetes, the final deployable output is usually a **container image**. This image is what later runs in development, staging, and production environments.

In a very small project, one developer might build an image on a laptop and run it locally. But in a real DevOps workflow, images must move between developers, CI/CD systems, test environments, Kubernetes clusters, and sometimes multiple data centers.

This movement cannot be manual, unclear, or dependent on one person's laptop. We need a central place where images are stored, versioned, controlled, scanned, and managed. That central place is called a **Container Registry**.

A registry is not just a file storage service. In DevOps, it becomes part of the software delivery chain:

```text
Developer pushes code
        |
        v
CI pipeline builds image
        |
        v
Image is pushed to registry
        |
        v
CD / Kubernetes pulls image
        |
        v
Application runs in the cluster
```

If the registry is unavailable, if tags are messy, if vulnerable images enter production, or if registry credentials are poorly managed, the entire deployment process becomes risky.

---

## 2. Basic Terms

Before understanding Harbor, we should separate several important terms.

### Registry

A **Registry** is the main service that stores and serves images or OCI artifacts.

Examples:

- Docker Hub
- GitLab Container Registry
- Harbor
- Amazon ECR
- Google Artifact Registry

Example registry address:

```text
harbor.example.com
```

### Repository

A **Repository** is a path inside the registry that usually represents one application, service, or image family.

Example:

```text
harbor.example.com/backend/payment-service
```

Here:

- `harbor.example.com` is the registry
- `backend/payment-service` is the repository path

### Image

A container **Image** is the packaged version of an application and its runtime dependencies.

Kubernetes normally does not build images. Kubernetes pulls already-built images and runs them as containers.

### Tag

A **Tag** identifies a specific version of an image.

Examples:

```text
payment-service:1.0.0
payment-service:2026-06-05
payment-service:commit-a1b2c3d
payment-service:latest
```

In production, avoid relying only on `latest`. Use traceable tags such as application version, build number, or commit SHA.

### Layer

An image is not a single flat file. It is made of multiple **layers**. Each layer usually comes from a Dockerfile instruction or a build step.

Layers help registries optimize storage and transfer. If multiple images share the same layers, the registry does not need to store and transfer everything again from zero.

### OCI Artifact

Modern registries are not only for Docker images. The OCI ecosystem allows registries to store other artifacts, such as:

- Container images
- Helm charts in OCI format
- Signatures
- SBOM files
- Supply-chain metadata
- Other OCI-compatible artifacts

So, Harbor should not be seen only as an image registry. It is better to see it as a secure **cloud-native artifact registry**.

---

## 3. What Is Harbor?

**Harbor** is an open-source, cloud-native registry platform designed for storing and managing container images and OCI artifacts securely.

A simple registry mainly answers two questions:

- Can I push this image?
- Can I pull this image?

Harbor answers many more operational and security questions:

- Who pushed this image?
- Who is allowed to pull it?
- Is this image vulnerable?
- Is this image signed?
- Should this image be replicated to another registry?
- Should old tags be removed automatically?
- Which project owns this image?
- Which robot account is used by CI/CD?
- How much storage is a project allowed to consume?

A simple analogy:

> A raw Docker Registry is like a simple warehouse. Harbor is like an enterprise warehouse with access control, security guards, inventory rules, reports, scanning, replication, and cleanup policies.

This is why Harbor is valuable in Kubernetes and DevOps courses. It teaches students how image management works in a real organization, not only how to push and pull a test image.

---

## 4. Harbor in a Real Pipeline

Imagine a team working on a service called `payment-service`.

The workflow can look like this:

```text
Developer
  |
  | git push
  v
CI Pipeline
  |
  | build + test
  v
Container Image
  |
  | docker push
  v
Harbor Registry
  |
  | scan + store + control access
  v
Kubernetes Deployment
  |
  | image pull
  v
Running Pod
```

After the CI system builds the image, it pushes the image to Harbor with a traceable tag, for example:

```text
harbor.example.com/backend/payment-service:commit-a1b2c3d
```

From that moment, Harbor can:

- Store the image
- Scan it for vulnerabilities
- Show scan results in the UI
- Limit who can pull or push it
- Keep audit records
- Apply retention policies
- Replicate it to another Harbor or registry

Later, Kubernetes does not build the image. Kubernetes pulls the exact image from Harbor and runs it.

This distinction matters:

> Kubernetes usually deploys a specific image. Therefore, image security, image versioning, and image access are part of production security.

---

## 5. Harbor vs Raw Docker Registry

A raw Docker Registry is lightweight and useful for simple labs. It can receive images and serve them back to clients.

However, real environments usually need more than simple push and pull.

| Feature | Raw Docker Registry | Harbor |
|---|---:|---:|
| Push/Pull images | Yes | Yes |
| Web UI | Usually no built-in enterprise UI | Yes |
| Project-based access control | Limited | Yes |
| Users and roles | Limited | Yes |
| Robot accounts | No native enterprise model | Yes |
| Vulnerability scanning | No | Yes, commonly with Trivy |
| Replication | No native enterprise workflow | Yes |
| Proxy cache | No or limited | Yes |
| Retention policies | No built-in enterprise model | Yes |
| Quota | No built-in enterprise model | Yes |
| Audit logs | Limited | Yes |

For a small lab, a raw registry may be enough. For teaching enterprise-like Kubernetes image management, Harbor is much better because it introduces the real concerns of DevOps platforms.

---

## 6. Harbor vs GitLab Container Registry

GitLab Container Registry is very convenient when a team already uses GitLab for source code, issues, and CI/CD.

A typical GitLab workflow looks like this:

```text
GitLab Repository
        |
        v
GitLab CI
        |
        v
GitLab Container Registry
```

This is simple and integrated.

Harbor has a different role. Harbor is not tied to a specific Git platform. You can push images to Harbor from:

- GitLab CI
- Jenkins
- GitHub Actions
- Tekton
- Argo Workflows
- Local Docker/Podman clients
- Other automation tools

So GitLab Registry is often excellent for GitLab-centered projects, while Harbor is better when you want a central, platform-independent registry for multiple teams, multiple CI/CD systems, and Kubernetes environments.

A simple classroom summary:

> GitLab Registry is close to GitLab projects. Harbor is closer to being a central organization-level registry.

---

## 7. Harbor vs Nexus Repository

Nexus Repository is a more general artifact repository manager. It can be used for many package types:

- Maven
- npm
- PyPI
- apt
- yum
- Docker images
- Other package formats

Nexus is strong when an organization wants one general platform for many kinds of artifacts and dependencies.

Harbor is more focused on cloud-native image and OCI artifact workflows. Its features are naturally connected to Kubernetes and container-image security:

- Image scanning
- Project-based image access
- OCI artifact support
- Replication
- Proxy cache
- Robot accounts
- Retention and quota
- Kubernetes-friendly registry workflows

Classroom summary:

> Nexus is a general artifact manager. GitLab Registry is tightly integrated with GitLab. Harbor is a specialized cloud-native registry for images and OCI artifacts with strong security and Kubernetes alignment.

---

## 8. Harbor Architecture Overview

Harbor is not a single binary or a single container. When installed on Kubernetes with Helm, it creates multiple services and components.

A simplified architecture looks like this:

```text
User / Docker CLI / CI Runner / Kubernetes Node
                |
                v
        https://harbor.example.com
                |
                v
        Ingress / Load Balancer
                |
                v
+---------------------------------------------+
|                  Harbor                     |
|                                             |
|  Portal  <-->  Core  <-->  Registry         |
|                |        \                   |
|                |         \                  |
|             Database     Storage            |
|                |                            |
|              Redis                           |
|                |                            |
|            Jobservice  <-->  Trivy Scanner  |
+---------------------------------------------+
```

### Main Components

| Component | Role |
|---|---|
| Portal | Web UI for users and administrators |
| Core | Main API and business logic: users, projects, permissions, policies |
| Registry | Stores and serves image manifests and layers |
| Database | Stores metadata: users, projects, permissions, scan results, configuration |
| Redis | Cache, sessions, queues, and coordination for some operations |
| Jobservice | Runs background jobs such as scanning, replication, garbage collection, and retention |
| Trivy Scanner | Scans images for known vulnerabilities |
| Ingress / Load Balancer | External entry point for browser, Docker clients, CI/CD, and Kubernetes nodes |
| PVC / Object Storage | Stores registry data and persistent component data |

A useful teaching analogy:

> Portal is the shop window. Core is the management office. Registry is the warehouse. Database is the archive. Redis is the fast memory and queue. Jobservice is the background worker team. Scanner is the security team. Ingress is the city gate.

---

## 9. Push and Pull Flow

### Push Flow

When a developer or CI runner pushes an image:

```text
Docker / CI Runner
        |
        | docker login
        | docker push
        v
Ingress / Load Balancer
        |
        v
Harbor Core checks authentication and permissions
        |
        v
Harbor Registry receives manifests and layers
        |
        v
Storage stores image data
        |
        v
Jobservice may trigger scan / replication / policy jobs
```

Important point:

> Harbor does not only receive bytes. It checks identity, project permissions, policies, and metadata.

### Pull Flow

When Kubernetes pulls an image:

```text
Kubernetes scheduler creates Pod
        |
        v
Kubelet on a worker node starts image pull
        |
        v
Container runtime contacts Harbor
        |
        v
Harbor checks authentication and authorization
        |
        v
Runtime downloads layers
        |
        v
Container starts
```

Important point:

> The application container does not pull the image itself. The image is pulled before the container starts by kubelet and the container runtime on the worker node.

This explains why TLS and certificate trust must be correct on worker nodes.

---

## 10. Projects and Access Control

In Harbor, images are usually organized inside **Projects**.

A project can represent:

- A team
- A product
- An environment
- A department
- A platform area

Examples:

```text
backend
frontend
platform
monitoring
production
staging
```

Projects help manage:

- Users
- Roles
- Robot accounts
- Repository permissions
- Quotas
- Scanner policies
- Retention rules
- Replication rules

A good design avoids putting everything into one flat shared space.

---

## 11. RBAC

Harbor supports role-based access control. This means users and robot accounts should receive only the permissions they need.

Common roles include project-level permissions such as:

- Admin or project admin
- Developer
- Guest
- Limited guest
- Maintainer-style operational roles depending on project policy

The exact model can change by Harbor version, but the principle is stable:

> Do not use the admin account for everyday CI/CD operations.

---

## 12. Robot Accounts

A Robot Account is a machine identity for automation.

It is commonly used by:

- CI/CD pipelines
- Build systems
- Deployment systems
- Kubernetes pull workflows

Why Robot Accounts matter:

- They avoid storing the Harbor admin password in pipelines
- They can be scoped to a project
- They can be given only push/pull permissions
- They can be rotated
- They make automation easier to audit

Recommended pattern:

| Use Case | Recommended Identity |
|---|---|
| Human administration | Human admin user |
| CI image push | Robot account with push/pull on one project |
| Kubernetes production pull | Pull-only robot account or limited user |
| Cross-registry replication | Dedicated robot or service identity |

---

## 13. Vulnerability Scanning

Harbor can scan images for known vulnerabilities. In many Harbor installations, this is done with **Trivy**.

The scanner checks the image against vulnerability databases and reports findings such as:

- CVE identifiers
- Severity levels
- Affected packages
- Fixed versions when available

Scanning does not magically make an image secure. It gives visibility and helps teams decide whether an image should be promoted or blocked.

In a mature workflow, scanning can be connected to policy:

```text
Image pushed
    |
    v
Scan image
    |
    v
Fail pipeline or block promotion if severity is too high
```

Harbor is one part of this security model. Kubernetes admission controllers such as Kyverno or Gatekeeper can also enforce runtime policies inside the cluster.

---

## 14. Image Signing, SBOM, and Supply Chain

Modern DevOps is not only about deploying quickly. It is also about knowing what is being deployed and whether it can be trusted.

Harbor can be part of a supply-chain workflow involving:

- Signed images
- SBOMs
- Provenance metadata
- OCI artifacts
- Policy checks

Image signing tools such as Cosign or Notation can be used in modern registry workflows.

The idea is simple:

> A registry should not only store images. It should help prove where images came from and whether they are trusted.

---

## 15. Replication

Replication allows Harbor to copy images between registries.

Common reasons for replication:

- Multiple data centers
- Disaster recovery
- Edge environments
- Separate staging and production registries
- Moving trusted images from one registry to another

Example:

```text
Harbor in Data Center A
        |
        | replication policy
        v
Harbor in Data Center B
```

Replication is useful when teams need local image availability or controlled promotion between environments.

---

## 16. Proxy Cache

Proxy Cache lets Harbor cache images from an upstream registry.

Example flow:

```text
Kubernetes / CI asks Harbor for nginx:alpine
        |
        v
Harbor checks local cache
        |
        | if missing
        v
Harbor pulls from Docker Hub
        |
        v
Harbor stores cached copy
```

Benefits:

- Less dependency on external registries
- Faster repeated pulls
- Reduced external bandwidth
- Better control over base images
- More stable CI/CD behavior

Proxy Cache is especially useful when many builds repeatedly pull the same base images.

---

## 17. Retention, Garbage Collection, and Quota

Registries can grow quickly. Every CI pipeline may push a new image tag. Without cleanup rules, storage can fill up.

Harbor helps with:

- **Retention policies**: decide which tags to keep or remove
- **Garbage collection**: remove unreferenced blobs and reclaim space
- **Quota**: limit storage usage by project

A common mistake is to install Harbor, push images successfully, and never configure retention or garbage collection. This works for a while, then storage fills up and pipelines start failing.

Production mindset:

> Registry storage must be managed from the beginning, not after it becomes full.

---

## 18. Audit and Visibility

Harbor provides visibility into registry activity.

This helps answer questions like:

- Who pushed this image?
- When was this tag created?
- Which user or robot account accessed this project?
- What vulnerabilities were found?
- Which policies are active?

In real DevOps teams, auditability is important because image changes can directly affect production.

---

## 19. Harbor and Helm Charts

Modern Helm supports OCI-based charts. This means a registry such as Harbor can also store Helm charts as OCI artifacts.

This is useful because teams can keep related delivery artifacts in one registry ecosystem:

```text
harbor.example.com/platform/nginx-controller-chart
harbor.example.com/backend/payment-service-image
harbor.example.com/security/signatures
```

The main idea:

> Harbor can store more than container images when the workflow uses OCI artifacts.

---

## 20. Harbor on Kubernetes with Helm: The Right Mindset

Installing Harbor with Helm is not just running one command.

Before installation, we should answer these questions:

1. What domain name will Harbor use?
2. Will Harbor be exposed through Ingress or LoadBalancer?
3. Will TLS be enabled?
4. Is the certificate public, private, or self-signed?
5. Where will registry data be stored?
6. Which StorageClass will PVCs use?
7. Are database and Redis internal or external?
8. How will backups work?
9. How will CI/CD authenticate?
10. How will Kubernetes pull private images?
11. How will retention and garbage collection be configured?
12. How will upgrades be handled?

Helm makes installation easier, but it does not remove architectural decisions.

---

## 21. Harbor High Availability

Harbor has both stateless and stateful parts.

Stateless-like components:

- Portal
- Core, depending on external state
- Jobservice workers, depending on configuration

Stateful components:

- Database
- Redis
- Registry storage
- Scanner cache/data

For real high availability, it is not enough to increase replica counts. We must also think about:

- External or HA PostgreSQL
- External or HA Redis
- Shared registry storage
- Object storage for registry blobs
- Highly available Ingress or Load Balancer
- Backup and restore
- Monitoring and alerting

For a classroom lab, a simple installation is fine. For production, HA is a design topic, not just a Helm option.

---

## 22. Storage Considerations

The most valuable data in Harbor is usually the registry storage: image layers and manifests.

If registry storage is lost, the UI alone cannot recover the pushed images.

For labs or small environments, PVC-based storage can be acceptable.

If using Longhorn, remember:

- Longhorn provides block-level replicated volumes
- It can be useful for small and medium environments
- It still requires snapshot/backup planning
- It is not the same design as large-scale object storage

For larger environments, object storage such as S3-compatible storage or MinIO can be a cleaner model for registry blobs.

Key lesson:

> A successful Helm install is not the same as a safe production registry.

---

## 23. Harbor and Kubernetes ImagePullSecret

If a Kubernetes Deployment uses a private image from Harbor, Kubernetes needs credentials.

Those credentials are normally stored as a Kubernetes Secret of type `docker-registry`.

Important notes:

- The secret must exist in the same namespace as the workload
- The Pod or ServiceAccount must reference it
- The credential must have permission to pull from the Harbor project
- TLS trust must be correct on the worker node

Flow:

```text
Harbor grants permission
        |
        v
Kubernetes stores credential as imagePullSecret
        |
        v
Kubelet and container runtime pull the image
        |
        v
Pod starts
```

If something is wrong, the Pod may stay in `ImagePullBackOff`.

---

## 24. Common Mistakes

### Mistake 1: Thinking Harbor is only a nice UI

Harbor is not just a pretty frontend for Docker Registry. Its main value is policy, access control, scanning, replication, proxy cache, quota, retention, and audit.

### Mistake 2: Using admin credentials in CI/CD

The admin user should be for administration, not everyday automation. Use robot accounts.

### Mistake 3: Using only `latest`

`latest` is not traceable enough for production. Use immutable and meaningful tags.

### Mistake 4: Ignoring TLS

A browser may open the Harbor UI, while Docker login or Kubernetes pull still fails because registry and token endpoints require correct TLS and `externalURL`.

### Mistake 5: No retention or garbage collection

Registry storage grows fast. Cleanup policies should be planned early.

### Mistake 6: No backup and restore practice

A backup is only useful if restore has been tested.

### Mistake 7: Treating lab installation as production design

A lab install proves concepts. Production requires storage, backup, monitoring, security, upgrades, and operational procedures.

---

## 25. Production-Readiness Checklist

Before using Harbor seriously, check:

- Stable DNS name
- Correct `externalURL`
- HTTPS with a trusted certificate
- Durable registry storage
- Backup and restore strategy
- Secure admin password handling
- Separate users and robot accounts
- Least-privilege access model
- Vulnerability scanning enabled
- Retention policy configured
- Garbage collection planned
- Project quotas configured
- Audit logs reviewed
- Upgrade process tested
- Monitoring and alerting configured
- CI/CD credentials stored securely
- Kubernetes pull credentials separated from push credentials

---

## 26. Suggested Transition to the Installation Demo

Now that we understand what Harbor is, we can install it on Kubernetes.

In the practical installation, we will not try to memorize every line of the Helm chart. Instead, we will follow these questions:

- What external address will Harbor use?
- How will it be exposed through NGINX Ingress?
- How will TLS be configured?
- Where will registry data be stored?
- Which StorageClass will be used?
- What is the admin password?
- How will Docker push an image?
- How will Kubernetes pull a private image?
- What changes if the certificate is public, private, self-signed, or if TLS is disabled for a lab?

This approach teaches architecture, not only commands.

---

## 27. Classroom Q&A Notes

### Does Harbor completely replace Docker Hub?

Inside an organization, Harbor can become the main private registry. But teams may still pull public base images from Docker Hub or other public registries. Harbor Proxy Cache can reduce direct dependency on external registries.

### Does Harbor itself stop unsafe images from running in Kubernetes?

Harbor can scan images and provide policy-related controls, but full runtime enforcement in Kubernetes often also needs admission controllers such as Kyverno or Gatekeeper.

### Is Harbor only for Docker images?

No. Harbor supports OCI artifacts, so it can also participate in Helm chart, signature, SBOM, and supply-chain workflows.

### Do we need full HA for a lab?

No. A simple install is enough for learning. But students should understand that production readiness requires storage design, backup, TLS, monitoring, access control, retention, and upgrade planning.

### What happens if Harbor is down?

Pods that already have images cached on their nodes may keep running. But new deployments, scaling to new nodes, and pulling new tags may fail.

---

## 28. Official References for Further Study

- Harbor official website: `https://goharbor.io/`
- Harbor documentation: `https://goharbor.io/docs/`
- Harbor Helm chart repository: `https://github.com/goharbor/harbor-helm`
- Harbor Helm repository: `https://helm.goharbor.io`
- Harbor GitHub releases: `https://github.com/goharbor/harbor/releases`
- Harbor Helm chart releases: `https://github.com/goharbor/harbor-helm/releases`
- Helm OCI registry documentation: `https://helm.sh/docs/topics/registries/`

---

## Final Teaching Summary

Harbor is a secure, cloud-native registry for managing container images and OCI artifacts. It is not only a storage location. It is a control point in the DevOps pipeline.

Images are built by developers or CI systems, pushed to Harbor, scanned and governed by Harbor, and later pulled by Kubernetes.

A raw Docker Registry is simple. GitLab Registry is convenient inside GitLab. Nexus is a general artifact repository manager. Harbor is specialized for cloud-native image and OCI artifact management with strong focus on Kubernetes, security, policy, replication, and enterprise workflow.

The practical installation with Helm is only the next step. The real skill is understanding what needs to be configured and why.
