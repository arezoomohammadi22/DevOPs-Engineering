# Kubernetes Secret for Private Docker Registry Authentication

This guide explains how to create a Kubernetes Secret of type `kubernetes.io/dockerconfigjson` to authenticate with a private container image registry (like DockerHub, GitLab, or Harbor) using a JSON config file.

---

## 📁 Step 1: Create Docker Auth JSON File

You can create the file manually or use the Docker CLI:

### ✅ Option 1: Use Docker CLI to generate

```bash
docker login myregistry.com
# This creates ~/.docker/config.json
```

### ✅ Option 2: Create it manually

Create a file named `config.json`:

```json
{
  "auths": {
    "myregistry.com": {
      "username": "myuser",
      "password": "mypassword",
      "auth": "bXl1c2VyOm15cGFzc3dvcmQ="  # base64(username:password)
    }
  }
}
```

---

## 📄 Step 2: Create the Secret

```bash
kubectl create secret generic regcred \
  --from-file=.dockerconfigjson=config.json \
  --type=kubernetes.io/dockerconfigjson
```

This creates a secret named `regcred` which Kubernetes can use to pull private images.

---

## 🐳 Step 3: Use Secret in Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-image-test
spec:
  containers:
    - name: app
      image: myregistry.com/myproject/myapp:latest
  imagePullSecrets:
    - name: regcred
```

---

## 🔐 Notes

- Secret type must be `kubernetes.io/dockerconfigjson`
- The key name must be `.dockerconfigjson` exactly
- The image registry URL in the config must match the domain in the image (e.g., `myregistry.com`)

---

## ✅ Verify

```bash
kubectl get secret regcred --output=yaml
```

Check that your pod can pull the private image:

```bash
kubectl describe pod private-image-test
```

---

🎉 Done! You’ve configured Kubernetes to pull private images using a secure registry secret.
