
# Terraform Modules Demo

This project demonstrates how to use **Terraform modules** to avoid code duplication.

We define a simple `nginx` module that creates a Kubernetes Namespace and a Deployment, and then we call this module twice from the root configuration.

---

## 📂 Project Structure
```
tf-modules-demo/
├── main.tf                # Root module, calls app1 and app2
└── modules/
    └── nginx/
        ├── main.tf        # Defines namespace + deployment
        ├── variables.tf   # Inputs: namespace, replicas, image
        └── outputs.tf     # Outputs: namespace
```

---

## 🚀 Usage

1. Ensure you have a running Kubernetes cluster and valid kubeconfig in `~/.kube/config`.
2. Adjust variables in the root `main.tf` if needed (namespace names, replicas, image).
3. Run:
```bash
terraform init
terraform apply -auto-approve
```

4. Verify resources:
```bash
kubectl get all -n app1
kubectl get all -n app2
```

---

## ⚙️ Variables (Module: nginx)
| Name        | Type   | Description                |
|-------------|--------|----------------------------|
| `namespace` | string | Namespace name             |
| `replicas`  | number | Number of replicas         |
| `image`     | string | Nginx image (e.g. nginx:1.25-alpine) |

---

## 🧹 Clean Up
```bash
terraform destroy -auto-approve
```

---

## 📌 Notes
- The `source` argument in the root `main.tf` must match your folder layout.  
  - If your root has `modules/nginx`, then use `source = "./modules/nginx"`.  
  - If you are inside the `modules` folder directly, use `source = "./nginx"`.  
