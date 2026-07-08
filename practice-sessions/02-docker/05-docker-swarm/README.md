# Docker Swarm Service Lab: Replicas, Routing Mesh, Scaling, Updates, Placement, and Publishing Modes

This lab is designed for a hands-on DevOps class where the Docker Swarm cluster is already prepared before the session starts. The goal is not only to run a container on a Swarm cluster. The goal is to help students see what Docker Swarm actually does after a service is created: how it schedules replicas, how it exposes an application through the routing mesh, how requests reach different tasks, how scaling changes the desired state, how rolling updates replace tasks gradually, and how placement rules influence where containers are allowed to run.

The lab uses one small HTTP application called **swarm-lab-app**. It is intentionally more useful than a basic `whoami` container. Every request returns runtime information such as the application version, the Swarm service name, the node hostname, the task name, the task slot, the container hostname, the container IP address, the request path, and a generated request ID. This lets students clearly observe which task answered each request and whether the answer came from version `v1` or `v2` during an update.

The application is simple, but the scenario is realistic. In a real company, you normally do not want to SSH into a random server and start containers manually. You want to describe the desired state of the application and let the orchestrator maintain it. Docker Swarm gives us that orchestration layer directly inside Docker Engine.

---

## 1. Prerequisites

Before starting the lab, the Swarm cluster must already exist.

A simple classroom topology can be:

```text
manager1   192.168.56.10
worker1    192.168.56.11
worker2    192.168.56.12
worker3    192.168.56.13
```

The commands that change the Swarm desired state must be executed on a manager node. Students can run read-only commands on other nodes, but service creation, service update, service scale, node labeling, and service removal should be done from `manager1`.

Check the cluster first:

```bash
docker node ls
```

Expected idea:

```text
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS
...                           manager1   Ready     Active         Leader
...                           worker1    Ready     Active
...                           worker2    Ready     Active
...                           worker3    Ready     Active
```

If you do not see the worker nodes, do not continue with the lab yet. Fix the cluster first, because most parts of this exercise depend on having multiple nodes.

The lab also assumes that every node can pull the application image. In a real Swarm cluster, this point is very important. When you create a service, the manager schedules tasks, but the worker node where a task lands must be able to pull the image. Therefore, the image should be pushed to a registry that all nodes can access, such as Docker Hub, GHCR, Harbor, GitLab Container Registry, or a private registry inside the lab network.

For the commands below, set these variables on the manager node:

```bash
export REGISTRY="YOUR_DOCKERHUB_USERNAME_OR_REGISTRY"
export IMAGE="$REGISTRY/swarm-lab-app"
```

Example:

```bash
export REGISTRY="mydockerhubuser"
export IMAGE="$REGISTRY/swarm-lab-app"
```

---

## 2. The Problem We Want to Demonstrate

Imagine that we have a small web application. On a single Docker host, we could run it like this:

```bash
docker run -d -p 8080:8080 myapp:v1
```

That works for a simple local test, but it does not solve the operational problems that appear in production.

A production-like environment needs answers to questions like these:

```text
What if the container dies?
What if the server dies?
How do we run three copies of the same application?
How do we expose the application without caring which exact server currently runs the container?
How do we update the application from v1 to v2 without stopping everything at once?
How do we force a service to run only on selected nodes?
How do we run one copy on every node, for example for monitoring agents or log collectors?
How do we publish a port through the Swarm routing mesh, and when should we bypass that routing mesh?
```

Docker Swarm is one solution to these problems. In Swarm, we do not mainly think in terms of individual containers. We think in terms of **services**. A service is the desired state of an application. We tell Swarm which image to use, how many replicas we want, which port to publish, which network to attach to, which nodes are allowed to run the tasks, and how updates should happen. Then Swarm tries to keep the real cluster state equal to that desired state.

This desired-state idea is the center of the whole lab.

---

## 3. Build the Lab Application

Create a repository with this structure:

```text
swarm-service-lab/
├── app/
│   └── server.py
├── Dockerfile
└── README.md
```

Create `app/server.py`:

```python
import json
import os
import socket
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

PORT = int(os.getenv("PORT", "8080"))
APP_VERSION = os.getenv("APP_VERSION", "v1")
START_TIME = time.time()


def get_container_ip() -> str:
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return "unknown"


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status_code: int, payload: dict) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed_path = urlparse(self.path)

        if parsed_path.path == "/health":
            if os.getenv("FORCE_UNHEALTHY", "false").lower() == "true":
                self._send_json(500, {
                    "status": "unhealthy",
                    "reason": "FORCE_UNHEALTHY=true"
                })
                return

            self._send_json(200, {
                "status": "ok",
                "app_version": APP_VERSION,
                "uptime_seconds": round(time.time() - START_TIME, 2)
            })
            return

        payload = {
            "message": "Hello from the Docker Swarm lab application",
            "app_version": APP_VERSION,
            "request_id": str(uuid.uuid4()),
            "request_path": parsed_path.path,
            "service_name": os.getenv("SERVICE_NAME", "unknown"),
            "node_name": os.getenv("NODE_NAME", "unknown"),
            "task_name": os.getenv("TASK_NAME", "unknown"),
            "task_slot": os.getenv("TASK_SLOT", "unknown"),
            "container_hostname": socket.gethostname(),
            "container_ip": get_container_ip(),
            "client_address": self.client_address[0],
            "uptime_seconds": round(time.time() - START_TIME, 2)
        }

        self._send_json(200, payload)

    def log_message(self, format: str, *args) -> None:
        print(f"{self.address_string()} - {format % args}")


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Starting swarm-lab-app {APP_VERSION} on port {PORT}")
    server.serve_forever()
```

Create `Dockerfile`:

```dockerfile
FROM python:3.12-alpine

ARG APP_VERSION=v1
ENV APP_VERSION=${APP_VERSION}
ENV PORT=8080

WORKDIR /app
COPY app/server.py /app/server.py

EXPOSE 8080

HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')"

CMD ["python", "server.py"]
```

This application gives us three important teaching advantages.

First, it shows which task answered the request. We pass Swarm metadata into the container using service templates. That lets the application return the node hostname, task name, and task slot.

Second, it has a visible version. When we update from `v1` to `v2`, the response changes, so students can see the rolling update happening.

Third, it has a health endpoint. This helps us demonstrate update behavior and rollback behavior when a bad configuration is introduced.

Build version `v1`:

```bash
docker build \
  --build-arg APP_VERSION=v1 \
  -t $IMAGE:v1 \
  .
```

Build version `v2`:

```bash
docker build \
  --build-arg APP_VERSION=v2 \
  -t $IMAGE:v2 \
  .
```

Push both images:

```bash
docker push $IMAGE:v1
docker push $IMAGE:v2
```

If the registry is private, log in from every node or use `--with-registry-auth` when creating or updating the service.

---

## 4. Create the Overlay Network

A service should not usually be attached only to the default network. In Swarm, an overlay network creates a distributed network across multiple Docker hosts. This means tasks running on different nodes can still communicate through the same logical network.

Create an overlay network:

```bash
docker network create \
  --driver overlay \
  swarm-lab-net
```

Inspect it:

```bash
docker network inspect swarm-lab-net
```

At this point, the network exists at the Swarm level. You created it once from the manager node, but services can use it even when their tasks run on worker nodes.

---

## 5. Create the First Service

Now we create the first service. This is the moment where students should understand the difference between `docker run` and `docker service create`.

With `docker run`, we ask one Docker Engine to start one container on one machine.

With `docker service create`, we ask the Swarm manager to create a desired state for the cluster. The manager decides where tasks should run, and workers run the actual containers.

Create the service with three replicas:

```bash
docker service create \
  --name swarm-lab-web \
  --replicas 3 \
  --network swarm-lab-net \
  --publish published=8080,target=8080,protocol=tcp,mode=ingress \
  --env SERVICE_NAME="{{.Service.Name}}" \
  --env NODE_NAME="{{.Node.Hostname}}" \
  --env TASK_NAME="{{.Task.Name}}" \
  --env TASK_SLOT="{{.Task.Slot}}" \
  --hostname "{{.Node.Hostname}}-{{.Task.Slot}}" \
  $IMAGE:v1
```

If you use a private registry, use this version:

```bash
docker service create \
  --with-registry-auth \
  --name swarm-lab-web \
  --replicas 3 \
  --network swarm-lab-net \
  --publish published=8080,target=8080,protocol=tcp,mode=ingress \
  --env SERVICE_NAME="{{.Service.Name}}" \
  --env NODE_NAME="{{.Node.Hostname}}" \
  --env TASK_NAME="{{.Task.Name}}" \
  --env TASK_SLOT="{{.Task.Slot}}" \
  --hostname "{{.Node.Hostname}}-{{.Task.Slot}}" \
  $IMAGE:v1
```

Now check the service:

```bash
docker service ls
```

You should see something like this:

```text
NAME            MODE         REPLICAS   IMAGE
swarm-lab-web   replicated   3/3        your-registry/swarm-lab-app:v1
```

The important part is `3/3`. The first number is the current running state. The second number is the desired state. If it says `1/3`, `2/3`, or `0/3`, Swarm has not yet reached the desired state. Maybe the image is still being pulled, maybe a node is not ready, maybe the registry cannot be reached, or maybe there is a constraint problem.

View the tasks:

```bash
docker service ps swarm-lab-web
```

This command is one of the most important commands in the lab. It shows the tasks that belong to the service and the node where each task is running.

Example idea:

```text
NAME              IMAGE                          NODE      DESIRED STATE   CURRENT STATE
swarm-lab-web.1   registry/swarm-lab-app:v1      worker1   Running         Running
swarm-lab-web.2   registry/swarm-lab-app:v1      worker2   Running         Running
swarm-lab-web.3   registry/swarm-lab-app:v1      worker3   Running         Running
```

A **task** is not exactly the same thing as a container, although in this lab each running task corresponds to a running container. The task is Swarm's scheduling unit. The service says, "I want three replicas." Swarm creates three tasks. Each task is assigned to a node. The node then creates the container for that task.

---

## 6. Test the Application and See Which Task Answers

Send requests to the service:

```bash
curl http://127.0.0.1:8080
```

Or from your laptop, use the IP address of any node:

```bash
curl http://192.168.56.10:8080
curl http://192.168.56.11:8080
curl http://192.168.56.12:8080
curl http://192.168.56.13:8080
```

The response should look similar to this:

```json
{
  "message": "Hello from the Docker Swarm lab application",
  "app_version": "v1",
  "request_id": "8efda06f-6f3e-4c1f-a5a7-cd40340c1a82",
  "request_path": "/",
  "service_name": "swarm-lab-web",
  "node_name": "worker2",
  "task_name": "swarm-lab-web.2.qk8p2z1...",
  "task_slot": "2",
  "container_hostname": "worker2-2",
  "container_ip": "10.0.1.17",
  "client_address": "10.0.0.2",
  "uptime_seconds": 53.21
}
```

Now run several requests in a loop:

```bash
for i in $(seq 1 15); do
  curl -s http://127.0.0.1:8080 | grep -E 'app_version|node_name|task_slot|container_hostname'
  echo "---"
done
```

If `jq` is installed, the output is easier to read:

```bash
for i in $(seq 1 15); do
  curl -s http://127.0.0.1:8080 | jq -r '"version=" + .app_version + " node=" + .node_name + " slot=" + .task_slot + " host=" + .container_hostname'
done
```

The point of this test is to show that one published service endpoint can lead to different tasks. You are not connecting directly to one fixed container. You are connecting to the service, and Swarm routes the request to one of the running tasks.

---

## 7. Understand Ingress Mode and the Routing Mesh

The service was published with this part:

```bash
--publish published=8080,target=8080,protocol=tcp,mode=ingress
```

This means:

```text
published=8080
```

Port `8080` is opened on the Swarm nodes as the externally reachable port.

```text
target=8080
```

Inside the container, the application listens on port `8080`.

```text
mode=ingress
```

The service uses the Swarm routing mesh.

The routing mesh is one of the most useful Swarm features to demonstrate in class. In ingress mode, the published port is available on every node in the swarm, even on a node that is not currently running a task for that service. When a request enters any node on the published port, Swarm can route it to an active task somewhere in the cluster.

This is the key classroom question:

```text
What happens if I send a request to a node that does not have a container for this service?
```

To demonstrate it, first find task placement:

```bash
docker service ps swarm-lab-web
```

Assume the output shows tasks on `worker1`, `worker2`, and `worker3`, but not on `manager1`. Now send a request to the manager IP:

```bash
curl http://192.168.56.10:8080
```

Even if `manager1` has no container for this service, the request can still succeed because `mode=ingress` uses the routing mesh. The node accepts the connection on the published port, and the routing mesh forwards it to one of the active tasks.

This is very different from manually running containers with `docker run -p`. With `docker run -p`, the port exists only on the host where the container is running. With Swarm ingress mode, the service port exists at the cluster edge.

That does not mean ingress mode is always the best option. It is a convenient default for many services, especially when you want simple cluster-wide exposure. However, if you need direct node-level port binding, custom external load balancing, or one task per node with direct access, host publishing mode can be more appropriate. We cover host mode later in this lab.

---

## 8. Replicated Mode

The service we created is a replicated service:

```bash
--replicas 3
```

We did not explicitly write `--mode replicated`, because replicated mode is the default mode for a Docker Swarm service. Still, it is useful to write it explicitly when teaching:

```bash
docker service create \
  --name swarm-lab-web-explicit \
  --mode replicated \
  --replicas 3 \
  --network swarm-lab-net \
  --publish published=8082,target=8080,mode=ingress \
  --env SERVICE_NAME="{{.Service.Name}}" \
  --env NODE_NAME="{{.Node.Hostname}}" \
  --env TASK_NAME="{{.Task.Name}}" \
  --env TASK_SLOT="{{.Task.Slot}}" \
  --hostname "{{.Node.Hostname}}-{{.Task.Slot}}" \
  $IMAGE:v1
```

In replicated mode, the important question is:

```text
How many copies of this service do we want?
```

If we say three replicas, Swarm tries to keep three tasks running. If a task dies, Swarm creates another task. If a node fails, Swarm reschedules the task on another available node. If we scale the service to six replicas, Swarm creates more tasks until the desired state becomes `6/6`.

It is important to tell students that replicated mode does not mean one task per node. It means a fixed number of replicas in the whole cluster. Swarm's scheduler decides where to place them. Depending on available nodes, constraints, resources, and current load, one node may run more than one replica, and another node may run none.

For many stateless web applications, replicated mode is the normal choice. The application is the same in every replica, and traffic can be distributed between replicas.

Remove the explicit demo service if you created it only for explanation:

```bash
docker service rm swarm-lab-web-explicit
```

---

## 9. Global Mode

Global mode answers a different question:

```text
Do we want exactly one task on every eligible node?
```

This is useful for things like monitoring agents, log collectors, node exporters, security agents, or infrastructure daemons. In those cases, we usually do not want a random number of replicas in the cluster. We want one task per node.

Create a global service using the same application but publish it on another port:

```bash
docker service create \
  --name swarm-lab-global \
  --mode global \
  --network swarm-lab-net \
  --publish published=8081,target=8080,protocol=tcp,mode=ingress \
  --env SERVICE_NAME="{{.Service.Name}}" \
  --env NODE_NAME="{{.Node.Hostname}}" \
  --env TASK_NAME="{{.Task.Name}}" \
  --env TASK_SLOT="{{.Task.Slot}}" \
  --hostname "{{.Node.Hostname}}-{{.Task.Slot}}" \
  $IMAGE:v1
```

Check it:

```bash
docker service ls
docker service ps swarm-lab-global
```

If your manager is active and allowed to run workloads, you may see one task on the manager too. This is an important teaching point. In Docker Swarm, a manager can also run workloads unless you drain it or use constraints to prevent scheduling on managers.

If you want the global service to run only on workers, create it with a placement constraint:

```bash
docker service create \
  --name swarm-lab-global-workers \
  --mode global \
  --constraint 'node.role==worker' \
  --network swarm-lab-net \
  --publish published=8083,target=8080,protocol=tcp,mode=ingress \
  --env SERVICE_NAME="{{.Service.Name}}" \
  --env NODE_NAME="{{.Node.Hostname}}" \
  --env TASK_NAME="{{.Task.Name}}" \
  --env TASK_SLOT="{{.Task.Slot}}" \
  --hostname "{{.Node.Hostname}}-{{.Task.Slot}}" \
  $IMAGE:v1
```

Now the scheduler should place one task on every worker that satisfies the constraint.

Try to scale a global service:

```bash
docker service scale swarm-lab-global=5
```

The command should fail because global services are not scaled by setting a replica number. Their scale is determined by the number of eligible nodes. If a new eligible node joins the swarm, Swarm creates a task there. If a node leaves or becomes unavailable, the global task for that node disappears or becomes unreachable.

Clean up the global demo services when you finish this section:

```bash
docker service rm swarm-lab-global swarm-lab-global-workers
```

---

## 10. Scaling a Replicated Service

Now return to the main service:

```bash
docker service ls
```

It should show `swarm-lab-web` with three replicas.

Scale it to six replicas:

```bash
docker service scale swarm-lab-web=6
```

Check the desired state:

```bash
docker service ls
docker service ps swarm-lab-web
```

Now run requests again:

```bash
for i in $(seq 1 20); do
  curl -s http://127.0.0.1:8080 | jq -r '"node=" + .node_name + " slot=" + .task_slot + " version=" + .app_version'
done
```

If `jq` is not installed:

```bash
for i in $(seq 1 20); do
  curl -s http://127.0.0.1:8080 | grep -E 'node_name|task_slot|app_version'
  echo "---"
done
```

Students should now see more task slots. Scaling did not require manually choosing machines. We did not SSH into three more nodes and run three more containers. We changed the service desired state from `3` to `6`, and Swarm created additional tasks.

Scale down to two replicas:

```bash
docker service scale swarm-lab-web=2
```

Check again:

```bash
docker service ls
docker service ps swarm-lab-web
```

When scaling down, Swarm removes extra tasks until the actual state matches the desired state. This is also desired-state management. The service definition says two replicas, so Swarm should not keep six running.

You can also scale by updating the service:

```bash
docker service update --replicas 4 swarm-lab-web
```

Both commands are valid for replicated services:

```text
docker service scale service_name=N
```

is a convenient scaling command.

```text
docker service update --replicas N service_name
```

is useful when scaling is part of a larger service update.

---

## 11. Limit Replicas per Node

Sometimes you want replicated mode, but you do not want Swarm to place multiple replicas of the same service on the same node. For example, if you have three replicas and three worker nodes, you may want each node to receive at most one replica.

This is not the same as global mode. In global mode, Swarm creates one task per eligible node. In replicated mode with a maximum-per-node rule, you still choose the replica count, but you limit how many tasks can land on each node.

Update the service:

```bash
docker service update \
  --replicas 3 \
  --replicas-max-per-node 1 \
  swarm-lab-web
```

Check placement:

```bash
docker service ps swarm-lab-web
```

Now Swarm should try to keep three replicas while allowing at most one replica per node.

This is useful when teaching the difference between these three ideas:

```text
Replicated mode:
Run N tasks somewhere in the cluster.

Replicated mode with --replicas-max-per-node 1:
Run N tasks, but do not put more than one task on the same node.

Global mode:
Run one task on every eligible node.
```

Reset the maximum-per-node rule if you want unrestricted scheduling later:

```bash
docker service update \
  --replicas-max-per-node 0 \
  swarm-lab-web
```

---

## 12. Rolling Update from v1 to v2

A rolling update replaces old tasks with new tasks gradually. This is one of the most important parts of the lab because students can see that Swarm does not need to stop the whole service before starting the new version.

First make sure the service is running version `v1`:

```bash
curl -s http://127.0.0.1:8080 | grep app_version
```

Scale the service to four replicas so that the update behavior is easier to see:

```bash
docker service scale swarm-lab-web=4
```

Run a watch command in one terminal:

```bash
watch -n 1 'docker service ps swarm-lab-web'
```

In another terminal, run requests repeatedly:

```bash
while true; do
  curl -s http://127.0.0.1:8080 | jq -r '"version=" + .app_version + " node=" + .node_name + " slot=" + .task_slot'
  sleep 1
done
```

Now update the image from `v1` to `v2`:

```bash
docker service update \
  --image $IMAGE:v2 \
  --update-parallelism 1 \
  --update-delay 10s \
  --update-order stop-first \
  swarm-lab-web
```

This command means:

```text
--image $IMAGE:v2
```

The service should now use the `v2` image.

```text
--update-parallelism 1
```

Update one task at a time.

```text
--update-delay 10s
```

Wait ten seconds between update batches.

```text
--update-order stop-first
```

Stop the old task first, then start the replacement task. This is the default behavior.

During the update, some requests may still return `v1`, while others may return `v2`. That is normal during a rolling update. Swarm is gradually replacing old tasks. The service is in a mixed-version state for a short time.

After the update finishes, all responses should show:

```json
"app_version": "v2"
```

Check the service history:

```bash
docker service ps swarm-lab-web
```

You may see old tasks with shutdown states and new tasks running. This is useful in class because it shows that an update creates replacement tasks instead of magically changing a running container in place.

---

## 13. Rolling Update with Parallelism, Delay, Monitor, Failure Action, and Start-First

Now we make the update strategy more production-like.

In real deployments, we usually care about how many tasks are updated at the same time, how long Swarm waits between update groups, what happens if a task fails, and whether the new task should start before the old task stops.

Run this update:

```bash
docker service update \
  --image $IMAGE:v1 \
  --update-parallelism 2 \
  --update-delay 5s \
  --update-order start-first \
  --update-monitor 20s \
  --update-failure-action rollback \
  --update-max-failure-ratio 0.25 \
  swarm-lab-web
```

This changes the service back to `v1`, but the real purpose is to explain the switches.

`--update-parallelism 2` means Swarm can update two tasks at the same time. If the service has six replicas, Swarm updates them in batches of two. This is faster than updating one at a time, but it also increases risk because more old capacity is replaced at once.

`--update-delay 5s` means Swarm waits five seconds between batches. This gives the cluster time to stabilize and gives you time to observe problems before the whole service is replaced.

`--update-order start-first` means Swarm tries to start the new task before stopping the old task. This can reduce downtime, but it requires enough resources to run the old and new task temporarily at the same time. It can also be tricky with host-mode port publishing if a fixed host port can only be used by one task on the same node.

`--update-monitor 20s` means Swarm monitors each updated task for twenty seconds to decide whether the update is healthy.

`--update-failure-action rollback` means Swarm should roll back automatically if the update fails beyond the allowed failure ratio.

`--update-max-failure-ratio 0.25` means the update can tolerate a limited failure ratio. If too many updated tasks fail, Swarm considers the update failed.

This is the part where students should understand that a rolling update is not just "change the image." A rolling update is a deployment policy. The policy defines speed, risk, health monitoring, and failure behavior.

---

## 14. Demonstrate a Failed Update and Automatic Rollback

The lab application supports a forced unhealthy mode through this environment variable:

```text
FORCE_UNHEALTHY=true
```

When this variable is set, `/health` returns HTTP 500, and the Docker health check fails.

First make sure the current service is healthy:

```bash
docker service ps swarm-lab-web
curl -s http://127.0.0.1:8080/health
```

Now trigger a bad update:

```bash
docker service update \
  --env-add FORCE_UNHEALTHY=true \
  --update-parallelism 1 \
  --update-delay 5s \
  --update-monitor 15s \
  --update-failure-action rollback \
  swarm-lab-web
```

Watch the tasks:

```bash
watch -n 1 'docker service ps swarm-lab-web'
```

The expected teaching point is that Swarm starts updating tasks, but the new tasks become unhealthy. Because the update policy says `rollback`, Swarm should attempt to return the service to the previous working specification.

After the rollback, inspect the service:

```bash
docker service inspect swarm-lab-web --pretty
```

Also check that the application is reachable again:

```bash
curl -s http://127.0.0.1:8080/health
curl -s http://127.0.0.1:8080 | grep app_version
```

If the service remains paused or partially updated, manually roll back:

```bash
docker service rollback swarm-lab-web
```

Then inspect again:

```bash
docker service ps swarm-lab-web
```

This section is powerful in a class because it shows that update strategy is not theory. A bad deployment can happen. Swarm gives us controls to reduce the blast radius and return to the previous state.

---

## 15. Manual Rollback

A manual rollback returns the service to the previous service specification.

For example, if you updated from `v1` to `v2`, and then you decide to go back:

```bash
docker service rollback swarm-lab-web
```

Check the result:

```bash
docker service ps swarm-lab-web
curl -s http://127.0.0.1:8080 | grep app_version
```

Rollback is not magic either. It is another controlled update operation. Swarm creates replacement tasks based on the previous specification.

You can also configure rollback behavior when updating a service:

```bash
docker service update \
  --rollback-parallelism 1 \
  --rollback-delay 5s \
  --rollback-order stop-first \
  swarm-lab-web
```

These rollback settings control how Swarm behaves if rollback is needed.

---

## 16. Placement Constraints

Now we move from scaling and updates to scheduling control.

By default, Swarm's scheduler chooses eligible nodes. But in real environments, not every service can run everywhere. Some services need SSD storage. Some should run only in a specific datacenter. Some should not run on manager nodes. Some require GPU nodes. Some should run only on nodes labeled as production nodes.

Placement constraints are hard rules. If a node does not match the constraint, Swarm must not place the task there.

First list nodes:

```bash
docker node ls
```

Add labels to nodes. Use your real node names from `docker node ls`:

```bash
docker node update --label-add disk=ssd worker1
docker node update --label-add disk=hdd worker2
docker node update --label-add disk=ssd worker3
```

Check node labels:

```bash
docker node inspect worker1 --pretty
docker node inspect worker2 --pretty
docker node inspect worker3 --pretty
```

Now create a service that can only run on SSD nodes:

```bash
docker service create \
  --name swarm-lab-ssd \
  --mode replicated \
  --replicas 2 \
  --constraint 'node.labels.disk==ssd' \
  --network swarm-lab-net \
  --publish published=8084,target=8080,protocol=tcp,mode=ingress \
  --env SERVICE_NAME="{{.Service.Name}}" \
  --env NODE_NAME="{{.Node.Hostname}}" \
  --env TASK_NAME="{{.Task.Name}}" \
  --env TASK_SLOT="{{.Task.Slot}}" \
  --hostname "{{.Node.Hostname}}-{{.Task.Slot}}" \
  $IMAGE:v1
```

Check placement:

```bash
docker service ps swarm-lab-ssd
```

The tasks should run only on nodes where `disk=ssd` exists.

Now intentionally create a constraint that cannot be satisfied:

```bash
docker service create \
  --name swarm-lab-gpu \
  --replicas 2 \
  --constraint 'node.labels.gpu==true' \
  --network swarm-lab-net \
  $IMAGE:v1
```

Check it:

```bash
docker service ls
docker service ps swarm-lab-gpu
```

The service may stay at `0/2`, and `docker service ps` should show that no suitable node is available. This is a valuable failure scenario. It teaches students that Swarm does not ignore constraints. If the desired state says two replicas but no node matches the rule, Swarm keeps the desired state but cannot make it real until an eligible node appears.

Now label a node:

```bash
docker node update --label-add gpu=true worker2
```

Check again:

```bash
docker service ps swarm-lab-gpu
```

Swarm should now be able to place tasks on the newly eligible node.

Remove the placement demo services:

```bash
docker service rm swarm-lab-ssd swarm-lab-gpu
```

---

## 17. Placement Preferences

Placement preferences are different from constraints.

A constraint is a hard rule:

```text
Only run on nodes where disk=ssd.
```

A preference is a soft scheduling preference:

```text
Try to spread replicas across zones.
```

Preferences are useful when you want better distribution, but you do not want the service to fail just because perfect distribution is impossible.

Add zone labels:

```bash
docker node update --label-add zone=az-a worker1
docker node update --label-add zone=az-b worker2
docker node update --label-add zone=az-b worker3
```

Create a service that spreads across zones:

```bash
docker service create \
  --name swarm-lab-spread \
  --replicas 6 \
  --placement-pref 'spread=node.labels.zone' \
  --network swarm-lab-net \
  --publish published=8085,target=8080,protocol=tcp,mode=ingress \
  --env SERVICE_NAME="{{.Service.Name}}" \
  --env NODE_NAME="{{.Node.Hostname}}" \
  --env TASK_NAME="{{.Task.Name}}" \
  --env TASK_SLOT="{{.Task.Slot}}" \
  --hostname "{{.Node.Hostname}}-{{.Task.Slot}}" \
  $IMAGE:v1
```

Check placement:

```bash
docker service ps swarm-lab-spread
```

Swarm tries to spread the tasks across the values of `node.labels.zone`. This is useful when you want replicas distributed across failure domains.

A good teaching example is:

```text
If all replicas are on one physical rack and that rack fails, the whole service is affected.
If replicas are spread across zones or racks, the failure impact is smaller.
```

Placement preferences are not the same as anti-affinity rules. They guide the scheduler, but they are not strict like constraints. If you need a hard rule, use constraints. If you need soft spreading, use placement preferences. If you also want to prevent too many replicas on one node, combine placement preferences with `--replicas-max-per-node`.

Remove the spread demo service:

```bash
docker service rm swarm-lab-spread
```

---

## 18. Host Mode vs Ingress Mode for Published Ports

So far, we used ingress mode:

```bash
--publish published=8080,target=8080,protocol=tcp,mode=ingress
```

Ingress mode means the Swarm routing mesh handles published traffic. Every node can accept traffic on the published port, even if the node does not run a task for the service.

Host mode is different:

```bash
--publish published=8090,target=8080,protocol=tcp,mode=host
```

Host mode publishes the port directly on the node where the task is running. There is no routing mesh for that published port. A request to a node only works if that node is actually running a task that has bound that port.

This distinction is very important.

Ingress mode is simple for users:

```text
Send traffic to any node on the published port.
Swarm routes the request to an active task.
```

Host mode is more direct:

```text
Send traffic only to nodes that actually run the task.
The port is bound directly on that node.
```

Create a host-mode service:

```bash
docker service create \
  --name swarm-lab-hostmode \
  --mode replicated \
  --replicas 3 \
  --network swarm-lab-net \
  --publish published=8090,target=8080,protocol=tcp,mode=host \
  --env SERVICE_NAME="{{.Service.Name}}" \
  --env NODE_NAME="{{.Node.Hostname}}" \
  --env TASK_NAME="{{.Task.Name}}" \
  --env TASK_SLOT="{{.Task.Slot}}" \
  --hostname "{{.Node.Hostname}}-{{.Task.Slot}}" \
  $IMAGE:v1
```

Check where tasks are running:

```bash
docker service ps swarm-lab-hostmode
```

Now test each node IP:

```bash
curl http://192.168.56.10:8090
curl http://192.168.56.11:8090
curl http://192.168.56.12:8090
curl http://192.168.56.13:8090
```

Only nodes running a task for this service should answer on port `8090`. Nodes without a task should not answer.

This is a major contrast with ingress mode. In ingress mode, a node without a task can still accept the published port and route the request. In host mode, the port belongs to the node running the task.

There is another important limitation. If you publish a fixed host port in host mode, one node usually cannot run multiple tasks of the same service that bind the same published port. The host port can only be bound once per node. If you try to run more replicas than there are eligible nodes, some tasks may remain pending or Swarm may need to place them only where the port is free.

For this reason, host mode is commonly used with global services or with constraints and external load balancers. A real production pattern can be:

```text
Run one reverse proxy task per worker node in host mode.
Put an external load balancer in front of the worker nodes.
The external load balancer sends traffic only to nodes that run the proxy.
```

Remove the host-mode service:

```bash
docker service rm swarm-lab-hostmode
```

---

## 19. A Good Classroom Flow

A strong teaching flow for this lab is to avoid starting with definitions. Start with the operational problem.

First, explain that a single container is not enough for production. Then create the first service with three replicas. Immediately show `docker service ls` and `docker service ps`. This connects the idea of desired state with a real command.

Second, test the service with repeated `curl` requests. Let students see that the application returns different node names and task slots. This makes load distribution visible.

Third, send traffic to a node that is not running a task. This is where ingress mode becomes understandable. Do not explain routing mesh only as a definition. Show the surprising result first: the request works even on a node without a task. Then explain why.

Fourth, compare replicated and global services. Use the same application so students do not get distracted by a new image. Explain that replicated mode is about a chosen number of replicas, while global mode is about one task per eligible node.

Fifth, scale the replicated service up and down. Connect scaling to desired state. Do not say only "we increased containers." Say "we changed the desired replica count, and Swarm reconciled the cluster."

Sixth, perform a rolling update. Keep one terminal watching `docker service ps` and another terminal sending repeated requests. Students should see both `v1` and `v2` during the transition.

Seventh, demonstrate a failed update. This makes `--update-failure-action rollback`, `--update-monitor`, and health checks meaningful.

Eighth, use placement constraints and preferences. Start with labels, then show a service that can only run on labeled nodes, then show a service that stays pending when no node matches.

Finally, compare ingress mode and host mode. This section should be done after students already understand services and task placement, because host mode only makes sense when they can read `docker service ps` and know which node has which task.

---

## 20. Useful Inspection and Troubleshooting Commands

List services:

```bash
docker service ls
```

Show service tasks:

```bash
docker service ps swarm-lab-web
```

Show full task errors:

```bash
docker service ps --no-trunc swarm-lab-web
```

Inspect service configuration:

```bash
docker service inspect swarm-lab-web --pretty
```

Show logs from all service tasks:

```bash
docker service logs swarm-lab-web
```

Follow logs:

```bash
docker service logs -f swarm-lab-web
```

Check containers on the current node:

```bash
docker ps
```

Check tasks running on a specific node:

```bash
docker node ps worker1
```

Check node details and labels:

```bash
docker node inspect worker1 --pretty
```

Check published ports:

```bash
docker service inspect swarm-lab-web --format '{{json .Endpoint.Ports}}'
```

Check whether the application is healthy:

```bash
curl http://127.0.0.1:8080/health
```

Common problems and what they usually mean:

```text
REPLICAS shows 0/3:
The tasks are not running. Check docker service ps --no-trunc.

Tasks show "Rejected":
Often image pull failure, bad command, port conflict, invalid mount, or unsupported platform.

Tasks show "Pending":
Often no suitable node because of constraints, resources, or port conflicts.

curl works on one node but not another in ingress mode:
Check firewall rules, published port, node connectivity, and whether the node is actually part of the swarm.

curl works only on nodes that run tasks:
You may be using host publishing mode, not ingress mode.

Service update does not roll forward:
Check health check, image pull access, update monitor, update failure action, and task errors.
```

---

## 21. Cleanup

Remove lab services:

```bash
docker service rm swarm-lab-web
```

Remove optional services if they still exist:

```bash
docker service rm \
  swarm-lab-global \
  swarm-lab-global-workers \
  swarm-lab-ssd \
  swarm-lab-gpu \
  swarm-lab-spread \
  swarm-lab-hostmode
```

Some of these may already be removed, so Docker may print an error for services that do not exist. That is fine.

Remove the overlay network:

```bash
docker network rm swarm-lab-net
```

Remove labels if you want to return nodes to their previous state:

```bash
docker node update --label-rm disk worker1
docker node update --label-rm disk worker2
docker node update --label-rm disk worker3

docker node update --label-rm gpu worker2

docker node update --label-rm zone worker1
docker node update --label-rm zone worker2
docker node update --label-rm zone worker3
```

---

## 22. Final Summary

In this lab, we started with a basic service and gradually added real Swarm behavior around it.

We created a service from an image, published it through ingress mode, and used the routing mesh to access it from different nodes. We used an application that exposes Swarm metadata in the HTTP response, so every request showed which node and task answered.

We compared replicated mode and global mode. Replicated mode runs a desired number of tasks in the cluster. Global mode runs one task on every eligible node.

We scaled the replicated service up and down and connected scaling to Swarm's desired-state model.

We updated the application from one version to another using rolling updates. Then we changed update behavior with parallelism, delay, start-first or stop-first order, monitor windows, failure actions, and rollback behavior.

We used placement constraints to create hard scheduling rules and placement preferences to guide distribution across labeled nodes. Finally, we compared ingress publishing mode with host publishing mode and explained why traffic behaves differently in each case.

The main idea students should remember is this:

```text
In Docker Swarm, we do not manually manage individual containers as the main unit.
We define services, desired state, placement rules, publishing behavior, scaling behavior, and update strategy.
Swarm continuously tries to make the real cluster match that desired state.
```

---

## References

This lab is based on Docker Engine Swarm mode behavior and the Docker CLI service commands documented by Docker:

- Docker Swarm mode overview
- Docker Swarm services
- Docker Swarm routing mesh and ingress publishing
- Docker service create
- Docker service update
- Docker service scale
- Docker node labels and placement constraints
