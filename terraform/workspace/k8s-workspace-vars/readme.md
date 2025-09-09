# Terraform Kubernetes Workspaces with Variables

This project demonstrates how to use **Terraform workspaces** and **workspace-specific variables** to deploy resources to multiple environments (dev, staging, prod) on a Kubernetes cluster.

---

## 📂 Project Structure
```
k8s-workspace-vars/
├── main.tf        # Terraform configuration (providers + resources)
├── variables.tf   # Workspace-specific variables
└── outputs.tf     # Outputs
```

---

## ⚙️ Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.x
- Access to a Kubernetes cluster
- `~/.kube/config` configured
- Permissions to create Namespaces, Deployments, Services

---

## 🔹 Variables
The project defines workspace-specific variables in `variables.tf`:
```hcl
variable "replica_count" {
  type = map(number)
  default = {
    dev     = 1
    staging = 2
    prod    = 3
  }
}

variable "image_tag" {
  type = map(string)
  default = {
    dev     = "nginx:1.25"
    staging = "nginx:1.25"
    prod    = "nginx:1.25"
  }
}
```
- `replica_count[terraform.workspace]` → number of replicas per environment
- `image_tag[terraform.workspace]` → container image per environment

---

## 🚀 Usage

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Create Workspaces
```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
```

### 3. Apply Terraform per Workspace
```bash
terraform workspace select dev
terraform apply -auto-approve

terraform workspace select staging
terraform apply -auto-approve

terraform workspace select prod
terraform apply -auto-approve
```
- Each workspace creates its own **namespace**, **deployment**, and **service**.
- `replicas` and `image` are set according to workspace-specific variables.

### 4. Destroy Resources
```bash
terraform workspace select dev
terraform destroy -auto-approve
```
Repeat for other workspaces as needed.

---

## 📌 Notes
- Workspaces isolate **state** for each environment, preventing conflicts.
- Using a **map variable** allows different configuration values per workspace without duplicating code.
- Outputs can be used to verify namespace, deployment, and service names per workspace.

---

## 🔗 References
- [Terraform Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)

