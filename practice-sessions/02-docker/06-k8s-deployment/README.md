# Kubernetes Deployment Lab: Dockerfile, Rolling Updates, Rollback, Probes, and Zero-Downtime Releases

This lab is designed for a DevOps class where students already have access to a Kubernetes cluster and want to understand how a real application is containerized, deployed, updated, monitored by probes, and rolled back safely.

The goal is not only to run a container on Kubernetes. The goal is to understand how Kubernetes decides when a Pod is healthy, when a Pod is ready to receive traffic, how a Deployment replaces old Pods with new Pods, and how update strategy settings such as `maxSurge` and `maxUnavailable` directly affect availability during a release.

In this exercise, we build a small HTTP application, write a Dockerfile for it, deploy it using a Kubernetes Deployment, expose it using a Service, update it using a rolling update strategy, intentionally break it, test rollback, and then add liveness, readiness, and startup probes.

The application is intentionally simple, but it is designed for teaching. Every HTTP response shows which Pod, Node, version, and container handled the request. This makes it much better than a generic `whoami` image because students can connect Kubernetes concepts directly to the response they see in the terminal.

---

## 1. What problem are we trying to solve?

Imagine that we have a small web application. In a non-orchestrated environment, we might run it manually with `docker run` on one server. That works for a demo, but it creates several problems in a real environment.

First, if the container dies, someone or something must restart it. Second, if we need more capacity, we have to manually start more containers. Third, if we want to release a new version, we must decide how to stop the old version and start the new one without breaking users' requests. Fourth, if the new version is broken, we need a safe way to roll back to the previous version.

Kubernetes solves these problems by giving us higher-level objects. Instead of saying, "run this container once", we say, "I want four replicas of this application to be running all the time." This desired state is defined using a Deployment. Kubernetes then continuously tries to make the real state match the desired state.

A Deployment manages ReplicaSets. ReplicaSets manage Pods. Pods run containers. When we update a Deployment, Kubernetes creates a new ReplicaSet for the new version and gradually shifts traffic from old Pods to new Pods, depending on the update strategy.

That is why this lab is built around Deployment. It gives us the best practical entry point for learning application rollout behavior in Kubernetes.

---

## 2. Prerequisites

Before starting this lab, the Kubernetes cluster should already be ready. Students do not need to create the cluster during this exercise.

You need:

- A working Kubernetes cluster such as Minikube, Kind, kubeadm, EKS, AKS, GKE, or any classroom cluster.
- `kubectl` configured and connected to the cluster.
- Docker or another container build tool installed locally.
- Access to a container registry if your cluster cannot use local images directly.
- Basic knowledge of Docker images, containers, ports, and Kubernetes YAML files.

Check cluster access:

```bash
kubectl get nodes
kubectl get namespaces
```

Create a namespace for this lab:

```bash
kubectl create namespace devops-lab
kubectl config set-context --current --namespace=devops-lab
```

From this point forward, commands are expected to run inside the `devops-lab` namespace.

---

## 3. Repository structure

Create a directory like this:

```text
k8s-deployment-update-probes-lab/
├── app.py
├── Dockerfile
└── k8s/
    ├── deployment-v1.yaml
    ├── service.yaml
    ├── deployment-rolling-update.yaml
    ├── deployment-recreate.yaml
    └── deployment-with-probes.yaml
```

The application and Kubernetes manifests are included below.

---

## 4. The demo application

The application is a small Python HTTP server. It has several endpoints:

- `/` returns application version, Pod name, Node name, Pod IP, hostname, and request ID.
- `/healthz` is used for liveness checks.
- `/readyz` is used for readiness checks.
- `/startupz` is used for startup checks.
- `/slow` simulates a slow request.

The application also supports intentional failures by checking files inside `/tmp`.

If `/tmp/live_fail` exists, `/healthz` fails.

If `/tmp/ready_fail` exists, `/readyz` fails.

If `/tmp/startup_fail` exists, `/startupz` fails.

This design allows students to test what happens when each type of probe fails.

Create `app.py`:

```python
import json
import os
import socket
import time
import uuid
from http.server import BaseHTTPRequestHandler, HTTPServer

APP_VERSION = os.getenv("APP_VERSION", "v1")
POD_NAME = os.getenv("POD_NAME", "unknown-pod")
POD_NAMESPACE = os.getenv("POD_NAMESPACE", "unknown-namespace")
POD_IP = os.getenv("POD_IP", "unknown-ip")
NODE_NAME = os.getenv("NODE_NAME", "unknown-node")
STARTUP_DELAY_SECONDS = int(os.getenv("STARTUP_DELAY_SECONDS", "0"))

START_TIME = time.time()


def json_response(handler, status_code, payload):
    body = json.dumps(payload, indent=2).encode("utf-8")
    handler.send_response(status_code)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def file_exists(path):
    return os.path.exists(path)


class DemoHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), format % args), flush=True)

    def do_GET(self):
        request_id = str(uuid.uuid4())
        uptime_seconds = int(time.time() - START_TIME)

        if self.path == "/":
            payload = {
                "message": "Hello from Kubernetes Deployment demo app",
                "app_version": APP_VERSION,
                "request_id": request_id,
                "pod_name": POD_NAME,
                "pod_namespace": POD_NAMESPACE,
                "pod_ip": POD_IP,
                "node_name": NODE_NAME,
                "container_hostname": socket.gethostname(),
                "uptime_seconds": uptime_seconds,
            }
            json_response(self, 200, payload)
            return

        if self.path == "/healthz":
            if file_exists("/tmp/live_fail"):
                json_response(self, 500, {
                    "status": "failed",
                    "probe": "liveness",
                    "reason": "/tmp/live_fail exists",
                    "app_version": APP_VERSION,
                    "pod_name": POD_NAME,
                })
                return

            json_response(self, 200, {
                "status": "ok",
                "probe": "liveness",
                "app_version": APP_VERSION,
                "pod_name": POD_NAME,
            })
            return

        if self.path == "/readyz":
            if file_exists("/tmp/ready_fail"):
                json_response(self, 503, {
                    "status": "not_ready",
                    "probe": "readiness",
                    "reason": "/tmp/ready_fail exists",
                    "app_version": APP_VERSION,
                    "pod_name": POD_NAME,
                })
                return

            if uptime_seconds < STARTUP_DELAY_SECONDS:
                json_response(self, 503, {
                    "status": "not_ready",
                    "probe": "readiness",
                    "reason": "application is still warming up",
                    "uptime_seconds": uptime_seconds,
                    "required_startup_delay_seconds": STARTUP_DELAY_SECONDS,
                    "app_version": APP_VERSION,
                    "pod_name": POD_NAME,
                })
                return

            json_response(self, 200, {
                "status": "ready",
                "probe": "readiness",
                "app_version": APP_VERSION,
                "pod_name": POD_NAME,
            })
            return

        if self.path == "/startupz":
            if file_exists("/tmp/startup_fail"):
                json_response(self, 503, {
                    "status": "startup_failed",
                    "probe": "startup",
                    "reason": "/tmp/startup_fail exists",
                    "app_version": APP_VERSION,
                    "pod_name": POD_NAME,
                })
                return

            if uptime_seconds < STARTUP_DELAY_SECONDS:
                json_response(self, 503, {
                    "status": "starting",
                    "probe": "startup",
                    "uptime_seconds": uptime_seconds,
                    "required_startup_delay_seconds": STARTUP_DELAY_SECONDS,
                    "app_version": APP_VERSION,
                    "pod_name": POD_NAME,
                })
                return

            json_response(self, 200, {
                "status": "started",
                "probe": "startup",
                "app_version": APP_VERSION,
                "pod_name": POD_NAME,
            })
            return

        if self.path == "/slow":
            time.sleep(10)
            json_response(self, 200, {
                "status": "slow response completed",
                "app_version": APP_VERSION,
                "pod_name": POD_NAME,
                "node_name": NODE_NAME,
            })
            return

        json_response(self, 404, {
            "error": "not found",
            "path": self.path,
        })


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    server = HTTPServer(("0.0.0.0", port), DemoHandler)
    print(f"Starting demo app version={APP_VERSION} port={port}", flush=True)
    server.serve_forever()
```

---

## 5. Dockerfile

The Dockerfile packages the Python application into a container image.

Create `Dockerfile`:

```dockerfile
FROM python:3.12-slim

ARG APP_VERSION=v1
ENV APP_VERSION=${APP_VERSION}
ENV PORT=8080

WORKDIR /app
COPY app.py /app/app.py

RUN useradd -r -u 10001 appuser
USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
```

This Dockerfile uses a small Python base image, copies the application into `/app`, runs it as a non-root user, exposes port `8080`, and starts the server.

The `APP_VERSION` build argument is important. We will build `v1`, `v2`, and intentionally broken versions to demonstrate update strategy and rollback.

---

## 6. Build and push the image

For a real Kubernetes cluster, the image must usually be available in a registry that all worker nodes can pull from.

Set your image name:

```bash
export IMAGE_REGISTRY="ghcr.io/YOUR_USERNAME"
export IMAGE_NAME="k8s-update-probes-demo"
export IMAGE_V1="$IMAGE_REGISTRY/$IMAGE_NAME:v1"
```

Build version `v1`:

```bash
docker build --build-arg APP_VERSION=v1 -t $IMAGE_V1 .
```

Push it:

```bash
docker push $IMAGE_V1
```

If you are using Minikube, you can build inside Minikube's Docker environment instead of pushing to a remote registry:

```bash
eval $(minikube docker-env)
docker build --build-arg APP_VERSION=v1 -t k8s-update-probes-demo:v1 .
```

If you are using Kind, you can load the image into the cluster:

```bash
docker build --build-arg APP_VERSION=v1 -t k8s-update-probes-demo:v1 .
kind load docker-image k8s-update-probes-demo:v1
```

For classroom simplicity, choose one image workflow before class and keep it consistent for all students.

---

## 7. First Deployment: run the application on Kubernetes

Now we create the first Deployment. This Deployment starts with three replicas. Three replicas are useful because rolling updates and readiness behavior are easier to observe when more than one Pod exists.

Create `k8s/deployment-v1.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-web
  labels:
    app: demo-web
spec:
  replicas: 3
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: demo-web
  template:
    metadata:
      labels:
        app: demo-web
    spec:
      containers:
        - name: demo-web
          image: ghcr.io/YOUR_USERNAME/k8s-update-probes-demo:v1
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          env:
            - name: APP_VERSION
              value: "v1"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
```

Replace the image name with your own image name.

Apply the Deployment:

```bash
kubectl apply -f k8s/deployment-v1.yaml
```

Watch the Pods:

```bash
kubectl get pods -w
```

See where the Pods are running:

```bash
kubectl get pods -o wide
```

This command is important for teaching. The `NODE` column tells students which Kubernetes worker node is running each Pod. When the application returns `node_name`, students can compare the HTTP response with `kubectl get pods -o wide` and understand that the request was handled by a specific Pod on a specific Node.

---

## 8. Expose the Deployment with a Service

A Deployment creates Pods, but users should not connect directly to Pod IPs. Pod IPs are temporary. If a Pod dies, Kubernetes creates a new Pod with a different IP.

A Service gives the application a stable network identity. The Service selects Pods using labels and load balances traffic across ready Pods.

Create `k8s/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-web
  labels:
    app: demo-web
spec:
  type: NodePort
  selector:
    app: demo-web
  ports:
    - name: http
      port: 80
      targetPort: 8080
      nodePort: 30080
```

Apply it:

```bash
kubectl apply -f k8s/service.yaml
```

Check the Service:

```bash
kubectl get service demo-web
```

If your cluster supports `LoadBalancer`, you can change `type: NodePort` to `type: LoadBalancer`. For classroom labs, `NodePort` is often easier because it works in many local and bare-metal setups.

Test the application:

```bash
curl http://NODE_IP:30080/
```

Send multiple requests:

```bash
for i in {1..10}; do
  curl -s http://NODE_IP:30080/ | grep -E 'app_version|pod_name|node_name|request_id'
  echo "---"
done
```

Students should see different Pod names in the responses. Depending on cluster networking and traffic distribution, they may also see different Node names.

This is the first important observation: the client sends traffic to one stable Service endpoint, but Kubernetes forwards the request to one of the backend Pods.

---

## 9. Why Deployment instead of directly creating Pods?

A Pod is the smallest deployable unit in Kubernetes, but a standalone Pod is not enough for production-style application management.

If a standalone Pod dies, Kubernetes may not recreate it in the way we expect. If we need three copies of the application, we would have to manage multiple Pods manually. If we want to update from version `v1` to version `v2`, a standalone Pod gives us no rollout history, no rolling update, and no rollback mechanism.

A Deployment solves these problems.

When we create a Deployment, Kubernetes creates a ReplicaSet. The ReplicaSet creates Pods. If a Pod disappears, the ReplicaSet creates another Pod. If we increase the number of replicas, the ReplicaSet creates more Pods. If we change the Pod template, the Deployment creates a new ReplicaSet and gradually replaces the old Pods with new Pods.

That is the reason this lab uses Deployment as the central object.

---

## 10. Deployment update strategies

A Deployment supports two main strategy types:

```yaml
strategy:
  type: RollingUpdate
```

or:

```yaml
strategy:
  type: Recreate
```

The default strategy is `RollingUpdate`. If you do not define the strategy explicitly, Kubernetes uses rolling update behavior.

The strategy controls how Kubernetes replaces old Pods when the Deployment's Pod template changes. A template change can be a new image, a new environment variable, a new label, a new probe, a new command, or another change under `.spec.template`.

This point is important: scaling a Deployment from 3 replicas to 5 replicas is not a rollout to a new revision. But changing the container image from `v1` to `v2` is a rollout because the Pod template changes.

---

## 11. Recreate strategy

The `Recreate` strategy is the simplest strategy, but it usually causes downtime.

With `Recreate`, Kubernetes terminates all old Pods first. After the old Pods are gone, it creates the new Pods. This means there can be a period where no Pod is available to serve traffic.

Create `k8s/deployment-recreate.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-web
  labels:
    app: demo-web
spec:
  replicas: 3
  revisionHistoryLimit: 5
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: demo-web
  template:
    metadata:
      labels:
        app: demo-web
    spec:
      containers:
        - name: demo-web
          image: ghcr.io/YOUR_USERNAME/k8s-update-probes-demo:v1
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          env:
            - name: APP_VERSION
              value: "v1"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
```

Apply it:

```bash
kubectl apply -f k8s/deployment-recreate.yaml
```

Now build and push version `v2`:

```bash
export IMAGE_V2="$IMAGE_REGISTRY/$IMAGE_NAME:v2"
docker build --build-arg APP_VERSION=v2 -t $IMAGE_V2 .
docker push $IMAGE_V2
```

Update the image:

```bash
kubectl set image deployment/demo-web demo-web=$IMAGE_V2
kubectl rollout status deployment/demo-web
```

While the update is happening, run this in another terminal:

```bash
while true; do
  curl -s --max-time 2 http://NODE_IP:30080/ || echo "request failed"
  echo "---"
  sleep 1
done
```

With `Recreate`, students may see failed requests because all old Pods are terminated before new Pods are available.

This strategy can still be useful in some cases. For example, if the application cannot run two versions at the same time because they conflict with each other, or if a migration requires all old instances to stop before new instances start, `Recreate` may be acceptable. But for most web applications that need high availability, `RollingUpdate` is preferred.

---

## 12. RollingUpdate strategy

The `RollingUpdate` strategy gradually replaces old Pods with new Pods. Instead of stopping everything at once, Kubernetes creates some new Pods, waits until they become ready, then removes some old Pods, and continues until the rollout is complete.

The behavior is controlled mainly by two fields:

```yaml
maxSurge
maxUnavailable
```

These two fields are extremely important for zero-downtime releases.

---

## 13. Understanding maxSurge

`maxSurge` defines how many extra Pods Kubernetes is allowed to create above the desired replica count during a rolling update.

Suppose the Deployment has:

```yaml
replicas: 4
```

If we set:

```yaml
maxSurge: 1
```

Kubernetes is allowed to temporarily run up to 5 Pods during the update. That means it can create one new Pod before deleting an old Pod.

This is useful because the new Pod can start, pass readiness checks, and become available before the old Pod is removed. This helps prevent downtime.

`maxSurge` can be an absolute number or a percentage:

```yaml
maxSurge: 1
```

or:

```yaml
maxSurge: 25%
```

If the desired replica count is 4 and `maxSurge` is `25%`, Kubernetes can temporarily create one extra Pod.

A higher `maxSurge` usually makes rollouts faster, but it requires extra cluster resources. A lower `maxSurge` uses fewer resources, but the rollout may take longer.

---

## 14. Understanding maxUnavailable

`maxUnavailable` defines how many desired Pods are allowed to be unavailable during a rolling update.

Suppose the Deployment has:

```yaml
replicas: 4
```

If we set:

```yaml
maxUnavailable: 0
```

Kubernetes must keep all 4 replicas available while the update is happening. This is a strong availability setting and is commonly used for zero-downtime web application updates.

If we set:

```yaml
maxUnavailable: 1
```

Kubernetes may allow one Pod to be unavailable during the rollout. This can make updates easier when the cluster has limited resources, but it also reduces available capacity during the rollout.

Like `maxSurge`, `maxUnavailable` can be a number or a percentage:

```yaml
maxUnavailable: 0
```

or:

```yaml
maxUnavailable: 25%
```

For zero-downtime updates, the common starting point is:

```yaml
maxSurge: 1
maxUnavailable: 0
```

or:

```yaml
maxSurge: 25%
maxUnavailable: 0
```

This means Kubernetes can add new Pods first and must not reduce the number of available Pods below the desired replica count.

A very important rule is that `maxSurge` and `maxUnavailable` cannot both be zero. If both are zero, Kubernetes has no legal way to update the Deployment. It is not allowed to create extra Pods, and it is not allowed to make any old Pod unavailable. Therefore, the rollout cannot proceed.

So if someone says, "keep `maxSurge` zero for zero downtime," that is usually not the right default for a normal web application. If `maxSurge: 0`, then `maxUnavailable` must be greater than zero. That means Kubernetes has to remove or make at least some old capacity unavailable before adding new capacity. In many web applications, the better zero-downtime pattern is `maxUnavailable: 0` with a positive `maxSurge`.

---

## 15. Rolling update manifest

Create `k8s/deployment-rolling-update.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-web
  labels:
    app: demo-web
spec:
  replicas: 4
  revisionHistoryLimit: 5
  minReadySeconds: 10
  progressDeadlineSeconds: 180
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: demo-web
  template:
    metadata:
      labels:
        app: demo-web
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: demo-web
          image: ghcr.io/YOUR_USERNAME/k8s-update-probes-demo:v1
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          env:
            - name: APP_VERSION
              value: "v1"
            - name: STARTUP_DELAY_SECONDS
              value: "3"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
```

Apply it:

```bash
kubectl apply -f k8s/deployment-rolling-update.yaml
kubectl rollout status deployment/demo-web
```

Check rollout history:

```bash
kubectl rollout history deployment/demo-web
```

Add a change-cause annotation so the revision is easier to understand later:

```bash
kubectl annotate deployment demo-web kubernetes.io/change-cause="Initial v1 deployment with rolling update strategy" --overwrite
```

Now update to version `v2`:

```bash
export IMAGE_V2="$IMAGE_REGISTRY/$IMAGE_NAME:v2"
docker build --build-arg APP_VERSION=v2 -t $IMAGE_V2 .
docker push $IMAGE_V2

kubectl set image deployment/demo-web demo-web=$IMAGE_V2
kubectl annotate deployment demo-web kubernetes.io/change-cause="Update app image from v1 to v2" --overwrite
kubectl rollout status deployment/demo-web
```

Watch the rollout in another terminal:

```bash
kubectl get pods -w
```

Also watch ReplicaSets:

```bash
kubectl get rs
```

During the rollout, students should see a new ReplicaSet appear. The new ReplicaSet scales up while the old ReplicaSet scales down.

This is the core mechanism of Deployment updates.

---

## 16. How to observe zero-downtime behavior

Run continuous requests during the rollout:

```bash
while true; do
  date
  curl -s --max-time 2 http://NODE_IP:30080/ | grep -E 'app_version|pod_name|node_name|request_id'
  echo "---"
  sleep 1
done
```

Then trigger another update.

Build version `v3`:

```bash
export IMAGE_V3="$IMAGE_REGISTRY/$IMAGE_NAME:v3"
docker build --build-arg APP_VERSION=v3 -t $IMAGE_V3 .
docker push $IMAGE_V3
```

Update the Deployment:

```bash
kubectl set image deployment/demo-web demo-web=$IMAGE_V3
kubectl annotate deployment demo-web kubernetes.io/change-cause="Update app image from v2 to v3" --overwrite
kubectl rollout status deployment/demo-web
```

Students should see some responses from `v2` and then some responses from `v3`. If readiness is configured correctly and the cluster has enough capacity, requests should continue succeeding during the update.

---

## 17. Rollback

A rollback means returning the Deployment to a previous revision.

Check rollout history:

```bash
kubectl rollout history deployment/demo-web
```

See details for a specific revision:

```bash
kubectl rollout history deployment/demo-web --revision=2
```

Rollback to the previous revision:

```bash
kubectl rollout undo deployment/demo-web
kubectl rollout status deployment/demo-web
```

Rollback to a specific revision:

```bash
kubectl rollout undo deployment/demo-web --to-revision=2
kubectl rollout status deployment/demo-web
```

After rollback, test the application again:

```bash
curl http://NODE_IP:30080/
```

The response should show the previous application version.

Rollback is possible because Deployment keeps older ReplicaSets according to `revisionHistoryLimit`. In this lab, we used:

```yaml
revisionHistoryLimit: 5
```

That means Kubernetes keeps enough history to allow rollback to recent versions.

---

## 18. Pause and resume rollout

Kubernetes also allows us to pause a rollout. This is useful when we want to make multiple changes but do not want Kubernetes to start rolling out each small change immediately.

Pause the Deployment:

```bash
kubectl rollout pause deployment/demo-web
```

Make a change:

```bash
kubectl set env deployment/demo-web DEMO_FLAG=enabled
```

The rollout will not proceed while paused.

Resume it:

```bash
kubectl rollout resume deployment/demo-web
kubectl rollout status deployment/demo-web
```

This is useful in controlled release workflows.

---

## 19. Probes in Kubernetes

Kubernetes probes are checks performed by the kubelet to understand the state of a container.

There are three main probe types:

- Liveness probe
- Readiness probe
- Startup probe

They may look similar because they often call similar endpoints, but they have very different meanings.

A liveness probe answers this question:

"Is this container still alive, or is it stuck in a broken state and needs to be restarted?"

A readiness probe answers this question:

"Is this Pod ready to receive traffic from the Service?"

A startup probe answers this question:

"Has this slow-starting application finished its initial startup process?"

Understanding the difference is one of the most important parts of writing production-grade Kubernetes manifests.

---

## 20. Probe handlers

A probe needs a handler. The handler defines how Kubernetes checks the container.

The most common handlers are:

```yaml
httpGet
```

```yaml
exec
```

```yaml
tcpSocket
```

Kubernetes also supports gRPC probes for applications that expose gRPC health checks.

---

## 21. HTTP GET handler

An HTTP GET probe sends an HTTP request to the container.

Example:

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: 8080
```

If the HTTP response status code is successful, Kubernetes considers the probe successful. For practical HTTP probes, status codes in the success range are treated as success, and error status codes such as `500` or `503` are treated as failure.

HTTP GET probes are very common for web applications because they are easy to understand and easy to test manually with `curl`.

In this lab, `/readyz`, `/healthz`, and `/startupz` are designed for HTTP probes.

---

## 22. Exec handler

An exec probe runs a command inside the container.

Example:

```yaml
livenessProbe:
  exec:
    command:
      - sh
      - -c
      - test ! -f /tmp/live_fail
```

If the command exits with status code `0`, the probe succeeds. If the command exits with a non-zero status code, the probe fails.

Exec probes are useful when the health condition is best checked from inside the container. For example, checking whether a local file exists, checking a local process, or running a small internal diagnostic command.

However, exec probes should be lightweight. A probe that runs a heavy command every few seconds can waste CPU and cause performance problems.

---

## 23. TCP socket handler

A TCP socket probe checks whether Kubernetes can open a TCP connection to a port inside the container.

Example:

```yaml
livenessProbe:
  tcpSocket:
    port: 8080
```

This is simpler than an HTTP probe. It only proves that something is listening on the port. It does not prove that the application is logically healthy.

For example, a web server might accept TCP connections but still return HTTP 500 for every request. A TCP probe would not catch that problem.

TCP probes are useful for simple network services, but for HTTP applications, HTTP GET probes usually provide better information.

---

## 24. gRPC handler

For gRPC applications, Kubernetes can use gRPC health checking.

A gRPC probe is useful when the application does not expose an HTTP endpoint and already implements the gRPC health checking protocol.

For this lab, we are using HTTP and exec probes because they are easier to demonstrate in class.

---

## 25. Probe timing fields

Each probe has timing fields that control how often Kubernetes checks the container and how many failures are tolerated.

`initialDelaySeconds` tells Kubernetes how long to wait after the container starts before running the probe for the first time.

`periodSeconds` controls how often the probe runs.

`timeoutSeconds` controls how long Kubernetes waits for a probe response before considering it failed.

`failureThreshold` controls how many consecutive failures are needed before Kubernetes takes action.

`successThreshold` controls how many consecutive successes are needed after a failure before the probe is considered successful again. For liveness and startup probes, this must be `1`. For readiness probes, it can be useful when you want a Pod to prove it is stable before receiving traffic again.

Example:

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
  successThreshold: 1
```

This means Kubernetes waits 3 seconds after container start, checks every 5 seconds, waits up to 2 seconds for each check, and marks readiness as failed after 3 consecutive failures.

---

## 26. Deployment with probes

Now create a better Deployment with startup, readiness, and liveness probes.

Create `k8s/deployment-with-probes.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-web
  labels:
    app: demo-web
spec:
  replicas: 4
  revisionHistoryLimit: 5
  minReadySeconds: 10
  progressDeadlineSeconds: 180
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: demo-web
  template:
    metadata:
      labels:
        app: demo-web
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: demo-web
          image: ghcr.io/YOUR_USERNAME/k8s-update-probes-demo:v1
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: APP_VERSION
              value: "v1"
            - name: STARTUP_DELAY_SECONDS
              value: "10"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          startupProbe:
            httpGet:
              path: /startupz
              port: http
            periodSeconds: 3
            timeoutSeconds: 2
            failureThreshold: 10
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
            successThreshold: 1
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          lifecycle:
            preStop:
              exec:
                command:
                  - sh
                  - -c
                  - sleep 10
```

Apply it:

```bash
kubectl apply -f k8s/deployment-with-probes.yaml
kubectl rollout status deployment/demo-web
```

Watch the Pods:

```bash
kubectl get pods -w
```

Describe a Pod:

```bash
kubectl describe pod POD_NAME
```

The `Events` section is very useful for teaching. It shows probe failures, restarts, scheduling behavior, image pulls, and readiness transitions.

---

## 27. What happens when readiness probe fails?

The readiness probe controls whether a Pod is included in Service traffic.

If readiness fails, Kubernetes does not restart the container just because readiness failed. Instead, the Pod remains running, but Kubernetes marks it as not ready. The Service removes that Pod from its ready endpoints, so normal Service traffic should stop going to it.

This is exactly what we want during startup, temporary dependency problems, graceful shutdown, or warm-up periods.

Test readiness failure:

```bash
POD=$(kubectl get pods -l app=demo-web -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- touch /tmp/ready_fail
```

Watch Pod readiness:

```bash
kubectl get pods
```

Check endpoints:

```bash
kubectl get endpoints demo-web -o wide
```

Send repeated requests:

```bash
for i in {1..20}; do
  curl -s http://NODE_IP:30080/ | grep pod_name
  sleep 1
done
```

The not-ready Pod should stop receiving traffic through the Service.

Fix readiness:

```bash
kubectl exec $POD -- rm /tmp/ready_fail
kubectl get pods
```

After the readiness probe succeeds again, the Pod can return to the Service endpoints.

This is one of the most important concepts for zero-downtime deployment. Kubernetes should only send traffic to Pods that are ready.

---

## 28. What happens when liveness probe fails?

The liveness probe controls whether Kubernetes should restart a container.

If liveness fails enough times according to `failureThreshold`, the kubelet restarts the container. This is useful when the application is deadlocked, stuck, or in a state that cannot recover without restart.

Test liveness failure:

```bash
POD=$(kubectl get pods -l app=demo-web -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- touch /tmp/live_fail
```

Watch restarts:

```bash
kubectl get pods -w
```

Describe the Pod:

```bash
kubectl describe pod $POD
```

You should eventually see the restart count increase.

After the container restarts, the `/tmp/live_fail` file usually disappears because the container filesystem is recreated. The application comes back clean.

This is a good teaching moment: liveness failure is much more aggressive than readiness failure. Readiness removes traffic. Liveness restarts the container.

For that reason, liveness probes should not check external dependencies such as a database, payment provider, or another microservice. If the database is temporarily slow and every application Pod restarts because of that, the outage can become worse.

A good liveness probe should answer: "Is this process alive and capable of recovering?"

A good readiness probe should answer: "Should this Pod receive user traffic right now?"

---

## 29. What happens when startup probe fails?

The startup probe is used for applications that need extra time to start.

When a startup probe is configured, Kubernetes waits for it to succeed before running liveness and readiness probes. This protects slow-starting applications from being killed too early by liveness checks.

If the startup probe keeps failing beyond its failure threshold, Kubernetes treats the container as failed and restarts it.

Test startup behavior by increasing startup delay:

```bash
kubectl set env deployment/demo-web STARTUP_DELAY_SECONDS=60
kubectl rollout status deployment/demo-web
```

Watch Pods:

```bash
kubectl get pods -w
```

Describe a new Pod:

```bash
kubectl describe pod POD_NAME
```

During startup, the application may not be ready yet. The startup probe gives it time. After startup succeeds, liveness and readiness checks begin normally.

This is better than setting a very long `initialDelaySeconds` on liveness. A long liveness delay means Kubernetes cannot detect real failures during that initial period. A startup probe gives the application a dedicated startup window, then allows normal liveness behavior after startup is complete.

---

## 30. HTTP probe and exec probe in the same lab

The previous manifest used HTTP probes for all three probe types. Now we can show an exec-based liveness probe.

Replace the liveness probe with this:

```yaml
livenessProbe:
  exec:
    command:
      - sh
      - -c
      - test ! -f /tmp/live_fail
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

This checks the same failure condition, but instead of calling `/healthz`, Kubernetes runs a command inside the container.

Test it:

```bash
POD=$(kubectl get pods -l app=demo-web -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- touch /tmp/live_fail
kubectl get pods -w
```

After enough failed checks, Kubernetes restarts the container.

This gives students a clear comparison:

HTTP GET probes are good when the application exposes health endpoints.

Exec probes are good when health can be checked locally inside the container.

TCP probes are good when only port availability matters.

---

## 31. Best practices for writing probes

Do not make liveness too strict. A strict liveness probe can restart containers unnecessarily. If a container is restarted repeatedly because of a temporary dependency issue, the system becomes less stable.

Do not use liveness to check database connectivity in most web applications. If the database has a short issue, restarting all application Pods does not fix the database. It only adds more load and causes more disruption.

Use readiness to control traffic. If the application cannot serve requests because a required dependency is unavailable, readiness can fail. That removes the Pod from Service traffic without restarting it.

Use startup probes for slow-starting applications. This is cleaner than using a very long liveness `initialDelaySeconds`.

Keep health endpoints cheap. A health endpoint should not run expensive database queries, heavy computations, or external API calls every few seconds.

Use realistic timeouts. If the application sometimes needs one second to answer during normal load, do not set `timeoutSeconds: 1` without testing. Too short a timeout causes false failures.

Use `failureThreshold` to avoid reacting to one small network hiccup. For example, a liveness probe with `periodSeconds: 10` and `failureThreshold: 3` gives the application about 30 seconds of repeated failure before restart.

For readiness, decide how quickly you want traffic removed. A lower failure threshold removes the Pod faster. A higher failure threshold avoids traffic removal during very short hiccups.

Make `/healthz`, `/readyz`, and `/startupz` separate endpoints if their meanings are different. This makes the application behavior easier to understand and prevents one endpoint from becoming overloaded with multiple meanings.

---

## 32. Best practices for zero-downtime rolling updates

For a typical stateless web application, start with at least two replicas. One replica is not enough for a meaningful zero-downtime rolling update. If there is only one replica and it must be replaced, there is always a risk that no ready Pod exists for a moment.

Use RollingUpdate, not Recreate:

```yaml
strategy:
  type: RollingUpdate
```

Use readiness probes. Without readiness probes, Kubernetes may consider a Pod available before the application is truly ready to handle traffic.

Use:

```yaml
maxUnavailable: 0
```

This tells Kubernetes not to reduce the number of available Pods during the rollout.

Use a positive `maxSurge`, such as:

```yaml
maxSurge: 1
```

or:

```yaml
maxSurge: 25%
```

This lets Kubernetes create new Pods before removing old ones.

Use `minReadySeconds` to make Kubernetes wait before considering a new Pod available:

```yaml
minReadySeconds: 10
```

This is useful because a Pod might pass readiness once and then fail immediately. `minReadySeconds` forces it to stay ready for a short period before it counts as available.

Use graceful shutdown. When Kubernetes terminates a Pod, it sends a termination signal. The application should stop accepting new traffic and finish existing requests if possible.

A simple classroom-friendly `preStop` hook is:

```yaml
lifecycle:
  preStop:
    exec:
      command:
        - sh
        - -c
        - sleep 10
```

This gives the cluster a little time to remove the Pod from endpoints before the process exits. In production, a better solution is for the application itself to handle shutdown gracefully.

Use enough `terminationGracePeriodSeconds`:

```yaml
terminationGracePeriodSeconds: 30
```

This gives the application time to finish in-flight requests before Kubernetes forcefully kills it.

Do not set both `maxSurge` and `maxUnavailable` to zero. Kubernetes does not allow that combination because it makes rollout impossible.

---

## 33. A recommended production-style starting point

For a normal stateless web application, this is a good starting point:

```yaml
replicas: 4
minReadySeconds: 10
progressDeadlineSeconds: 180
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

And use probes like this:

```yaml
startupProbe:
  httpGet:
    path: /startupz
    port: http
  periodSeconds: 3
  timeoutSeconds: 2
  failureThreshold: 10

readinessProbe:
  httpGet:
    path: /readyz
    port: http
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 2

livenessProbe:
  httpGet:
    path: /healthz
    port: http
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

This setup gives the application time to start, prevents traffic from going to unready Pods, and restarts the container only when it appears truly unhealthy.

---

## 34. What if maxSurge is 0?

Sometimes teams set:

```yaml
maxSurge: 0
```

This means Kubernetes cannot create extra Pods above the desired replica count during the update.

If `maxSurge` is zero, then `maxUnavailable` must be greater than zero. Otherwise, Kubernetes cannot proceed.

Example:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0
    maxUnavailable: 1
```

This update strategy is useful when the cluster has no extra capacity to run additional Pods during rollout. However, it means Kubernetes may reduce available capacity during the update.

For example, with 4 replicas and `maxUnavailable: 1`, Kubernetes can take one old Pod down before creating a new one. If the remaining Pods can handle the traffic, users may not notice. But it is not as strong as `maxUnavailable: 0` with a positive `maxSurge`.

So for zero-downtime releases, do not blindly set `maxSurge: 0`. First ask whether the cluster has enough spare capacity. If it does, prefer `maxUnavailable: 0` and a positive `maxSurge`.

---

## 35. Progress deadline and failed rollout

`progressDeadlineSeconds` defines how long Kubernetes waits for a Deployment rollout to make progress before marking it as failed.

Example:

```yaml
progressDeadlineSeconds: 180
```

If the new Pods cannot become ready, Kubernetes eventually marks the Deployment as not progressing.

This does not automatically roll back the Deployment by itself. It marks the rollout as failed so that operators or automation can react.

You can inspect the status:

```bash
kubectl rollout status deployment/demo-web
kubectl describe deployment demo-web
```

To simulate a failed rollout, set a broken readiness condition. For example, deploy a version with a startup delay longer than the progress deadline, or create a readiness endpoint that always returns failure.

Then rollback manually:

```bash
kubectl rollout undo deployment/demo-web
kubectl rollout status deployment/demo-web
```

This is a good classroom scenario because students can see that Kubernetes does not simply send traffic to broken Pods if readiness is configured correctly.

---

## 36. Complete classroom flow

Start with the problem: running containers manually is not enough for production because we need self-healing, scaling, update control, health checking, and rollback.

Build the application image:

```bash
docker build --build-arg APP_VERSION=v1 -t $IMAGE_V1 .
docker push $IMAGE_V1
```

Deploy version `v1`:

```bash
kubectl apply -f k8s/deployment-v1.yaml
kubectl apply -f k8s/service.yaml
kubectl get pods -o wide
```

Send requests and observe Pod and Node names:

```bash
curl http://NODE_IP:30080/
```

Explain Deployment, ReplicaSet, Pod, and Service.

Then explain update strategy.

Apply the rolling update manifest:

```bash
kubectl apply -f k8s/deployment-rolling-update.yaml
```

Build and push `v2`:

```bash
docker build --build-arg APP_VERSION=v2 -t $IMAGE_V2 .
docker push $IMAGE_V2
```

Update the Deployment:

```bash
kubectl set image deployment/demo-web demo-web=$IMAGE_V2
kubectl rollout status deployment/demo-web
```

Watch Pods and ReplicaSets:

```bash
kubectl get pods -w
kubectl get rs
```

Rollback:

```bash
kubectl rollout undo deployment/demo-web
kubectl rollout status deployment/demo-web
```

Then add probes:

```bash
kubectl apply -f k8s/deployment-with-probes.yaml
```

Test readiness failure:

```bash
POD=$(kubectl get pods -l app=demo-web -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- touch /tmp/ready_fail
kubectl get endpoints demo-web -o wide
kubectl exec $POD -- rm /tmp/ready_fail
```

Test liveness failure:

```bash
kubectl exec $POD -- touch /tmp/live_fail
kubectl get pods -w
```

Finally, explain zero-downtime best practices:

```yaml
replicas: 4
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
readinessProbe:
  httpGet:
    path: /readyz
    port: http
```

The key message is that zero-downtime deployment is not created by one field. It is the result of multiple correct decisions: multiple replicas, rolling update strategy, positive surge capacity, zero unavailable Pods, readiness checks, graceful shutdown, and enough cluster resources.

---

## 37. Useful troubleshooting commands

Check Deployments:

```bash
kubectl get deployments
kubectl describe deployment demo-web
```

Check ReplicaSets:

```bash
kubectl get rs
```

Check Pods:

```bash
kubectl get pods -o wide
kubectl describe pod POD_NAME
```

Check logs:

```bash
kubectl logs POD_NAME
```

Follow logs:

```bash
kubectl logs -f POD_NAME
```

Check Service:

```bash
kubectl get service demo-web
kubectl describe service demo-web
```

Check endpoints:

```bash
kubectl get endpoints demo-web -o wide
```

Check rollout status:

```bash
kubectl rollout status deployment/demo-web
```

Check rollout history:

```bash
kubectl rollout history deployment/demo-web
```

Rollback:

```bash
kubectl rollout undo deployment/demo-web
```

Watch events:

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

## 38. Cleanup

Delete the lab resources:

```bash
kubectl delete namespace devops-lab
```

If you used local images in Minikube or Kind, you can remove them from your local Docker environment if needed.

---

## 39. Final summary

In this lab, students learned how to take a containerized application and run it as a Kubernetes Deployment. They saw why Deployment is better than manually running Pods. They observed how a Service sends traffic to different Pods. They learned how rolling updates work and how Kubernetes creates a new ReplicaSet for a new version.

They also learned that update strategy is not just a YAML detail. `maxSurge` and `maxUnavailable` directly control availability during releases. `Recreate` is simple but usually causes downtime. `RollingUpdate` is the normal choice for web applications.

Most importantly, students learned that probes are part of the release strategy. Readiness controls traffic. Liveness controls restarts. Startup protects slow-starting applications. If these probes are written incorrectly, Kubernetes may restart healthy applications, send traffic to unready applications, or hide real failures.

A safe zero-downtime release normally requires multiple replicas, a rolling update strategy, `maxUnavailable: 0`, a positive `maxSurge`, correct readiness probes, graceful shutdown, and enough cluster capacity.

---

## 40. Official references

- Kubernetes Deployments: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- Update a Deployment without downtime: https://kubernetes.io/docs/tasks/run-application/update-deployment-rolling/
- Liveness, readiness, and startup probes: https://kubernetes.io/docs/concepts/workloads/pods/probes/
- Configure probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- Pod lifecycle and startup probe behavior: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
- Kubernetes Deployment API reference: https://kubernetes.io/docs/reference/kubernetes-api/apps/deployment-v1/
