
# Terraform Kubernetes Demo – Resource + Data Source

This project demonstrates how to use **Resource** and **Data Source** together in Terraform with the Kubernetes provider:

- **Data Source**: reads an existing Kubernetes Secret (`db-credentials`).
- **Resource**: creates a Deployment and Service that consume the Secret as environment variables.

---

## 📂 Project Structure
```
tf-k8s-secret-demo/
├── main.tf        # Provider + Deployment + Service
├── variables.tf   # Input variables (namespace, secret name, image, ...)
├── outputs.tf     # Outputs (Secret name, NodePort, ...)
└── README.md
```

---

## 🚀 Prerequisites
- A running Kubernetes cluster (minikube, kind, or cloud cluster).
- Valid kubeconfig at `~/.kube/config`.
- An existing Secret in the target namespace (e.g., `db-credentials`).

### Create a sample Secret
```bash
kubectl -n default create secret generic db-credentials   --from-literal=username=myuser   --from-literal=password=supersecret
```

---

## ⚙️ Variables
| Name          | Default                        | Description |
|---------------|--------------------------------|-------------|
| `namespace`   | default                        | Target namespace |
| `secret_name` | db-credentials                 | Existing Secret name |
| `app_name`    | k8s-data-vs-resource-demo      | Application name |
| `image`       | nginx:1.25-alpine              | Container image |
| `service_type`| NodePort                       | Service type (NodePort/ClusterIP/LoadBalancer) |
| `service_port`| 80                             | Service port |
| `replicas`    | 2                              | Deployment replicas |

---

## ▶️ Usage
```bash
terraform init
terraform apply -auto-approve
```

---

## 🔍 Verify
```bash
kubectl get all -n default
```

If the Service type is NodePort:
```bash
kubectl get svc -n default
```
Then open in browser:  
`http://<NodeIP>:<NodePort>`

---

## 📤 Outputs
- `secret_used` → Secret name read by data source  
- `service_type` → Type of Service created  
- `node_port` → NodePort number (if applicable)  
- `hint` → Access instructions  

---

## 🧹 Clean Up
```bash
terraform destroy -auto-approve
```

---

✅ This project shows how to combine a **Data Source** (read existing Secret) with **Resources** (Deployment + Service).
