# Terraform Kubernetes Workspaces Example

This project shows how to manage multiple environments (e.g. **dev**, **prod**) in Kubernetes using Terraform **workspaces**.  
Each workspace will create its own Kubernetes **namespace** and deploy an **nginx** Deployment inside it.

---

## 📂 Project Structure
```
.
├── main.tf        # Terraform config (providers + resources)
```

---

## ⚙️ Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.x
- Access to a Kubernetes cluster
- `~/.kube/config` configured (e.g. from `kubectl config view`)
- Permissions to create Namespaces, Deployments

---

## 🚀 Usage

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Create Workspaces
Terraform uses workspaces to separate **state** for each environment.
```bash
terraform workspace new dev
terraform workspace new prod
```

List workspaces:
```bash
terraform workspace list
```

### 3. Apply Terraform in a Workspace
Switch to the workspace you want and apply:
```bash
terraform workspace select dev
terraform apply -auto-approve
```
This will create:
- Namespace: `dev-namespace`
- Deployment: `nginx` in `dev-namespace`

Switch to `prod` workspace:
```bash
terraform workspace select prod
terraform apply -auto-approve
```
- Namespace: `prod-namespace`
- Deployment: `nginx` in `prod-namespace`

### 4. Destroy Resources
To remove resources in a specific workspace:
```bash
terraform workspace select dev
terraform destroy -auto-approve
```

---

## 🟢 Notes
- **Workspaces** allow you to use the same Terraform code for multiple environments with separate state files.
- Each workspace creates **isolated Kubernetes namespaces**, so resources do not collide.
- You can access the current workspace inside Terraform using `terraform.workspace`.
- Recommended workflow for teams: apply changes first to `dev`, then `prod` after testing.

---

## 🔗 Reference
- [Terraform Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)

