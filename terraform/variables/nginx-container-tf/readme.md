
# Terraform Docker Variables Example

This project demonstrates how to use **Terraform variables** with the **Docker provider** to manage multiple Nginx containers.

---

## 📂 Project Structure
```
project/
├── main.tf
├── variables.tf
└── outputs.tf
```

---

## 🚀 How It Works

- Uses the **Docker provider**.
- Pulls the `nginx:latest` image (configurable).
- Starts multiple Nginx containers, based on a variable `container_count`.
- Each container maps port `80` internally to a unique external port (starting from `http_port_start`).

---

## ⚙️ Variables

Defined in `variables.tf`:

| Name              | Type   | Default         | Description               |
|-------------------|--------|-----------------|---------------------------|
| `container_count` | number | `2`             | Number of Nginx containers |
| `nginx_image`     | string | `nginx:latest`  | Docker image for Nginx    |
| `http_port_start` | number | `8080`          | First external port       |

---

## 🔧 Usage

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Apply with Defaults
```bash
terraform apply -auto-approve
```

This will run **2 containers**:
- `nginx_1` on `http://localhost:8080`
- `nginx_2` on `http://localhost:8081`

### 3. Override Variables
Example: run 3 containers starting at port 9000:
```bash
terraform apply -auto-approve -var="container_count=3" -var="http_port_start=9000"
```

Containers:
- `nginx_1` → port 9000  
- `nginx_2` → port 9001  
- `nginx_3` → port 9002  

---

## 📤 Outputs

After apply, Terraform prints a list of running containers with their URLs, for example:
```
nginx_1 -> http://localhost:8080
nginx_2 -> http://localhost:8081
```

---

## 🧹 Clean Up
To stop and remove all containers created by Terraform:
```bash
terraform destroy -auto-approve
```

---

## 📌 Notes
- Ensure Docker is installed and the daemon is running.  
- Terraform will manage only the resources it created.  
