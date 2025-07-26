# TLS-Enabled NGINX Deployment with Kubernetes Secret

This guide shows you how to:

1. Create a TLS Secret (two methods)
2. Deploy NGINX
3. Expose NGINX via a Service
4. Secure it with an Ingress and your TLS secret

---

## 🔐 Step 1: Create TLS Secret

You can create the TLS secret using either:

### ✅ Option 1: Using `kubectl create secret tls`

```bash
kubectl create secret tls my-tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  --namespace=default
```

This will automatically:
- Encode the files using base64
- Set `type: kubernetes.io/tls`
- Create fields: `tls.crt` and `tls.key`

---

### ✅ Option 2: Write the YAML Manually (base64 required)

First, encode your cert and key:

```bash
cat tls.crt | base64 -w 0
cat tls.key | base64 -w 0
```

Then create the YAML file:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-tls-secret
  namespace: default
type: kubernetes.io/tls
data:
  tls.crt: <BASE64_ENCODED_CERT>
  tls.key: <BASE64_ENCODED_KEY>
```

Apply the secret:

```bash
kubectl apply -f tls-secret.yaml
```

---

## 🚀 Step 2: Deploy NGINX

### `nginx-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:stable
          ports:
            - containerPort: 80
```

---

## 🌐 Step 3: Expose NGINX with a Service

### `nginx-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

---

## 🔒 Step 4: Add Ingress with TLS

### `nginx-ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - example.local
      secretName: my-tls-secret
  rules:
    - host: example.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```

---

## ✅ Final Step: Apply All Resources

```bash
kubectl apply -f tls-secret.yaml     # if you're using YAML method
kubectl apply -f nginx-deployment.yaml
kubectl apply -f nginx-service.yaml
kubectl apply -f nginx-ingress.yaml
```

Add the following line to your `/etc/hosts` to test locally:

```
127.0.0.1 example.local
```

---

🎉 Done! Your NGINX app is now served securely over HTTPS using your own TLS secret.
