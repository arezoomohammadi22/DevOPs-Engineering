# 🛡️ Rancher Agent CA Configuration (Strict TLS Mode)

This guide explains how to manually configure Rancher Agent (`cattle-cluster-agent`) to trust your Rancher server certificate, especially when switching `agent-tls-mode` to `strict`.

---

## 📌 Why This Matters

When `agent-tls-mode` is set to `strict`, Rancher agents must verify the Rancher server's TLS certificate using a trusted Certificate Authority (CA). If this CA is not present inside the agent container, you'll see errors like:

```
unable to read CA file from /etc/kubernetes/ssl/certs/serverca
Strict CA verification is enabled but encountered error finding root CA
```

---

## ✅ Alternative: Use `agent-tls-mode: system-store` (Recommended for Let's Encrypt)

If your Rancher server uses a **publicly trusted certificate** (e.g., Let's Encrypt), you can avoid manual CA injection by simply switching the TLS mode to `system-store`.

### Steps to Change in Rancher UI:

1. Go to **Global Settings**
2. Search for `agent-tls-mode`
3. Click **Edit**
4. Set value to: `system-store`
5. Click **Save**

✅ With this setting, Rancher agents will trust any certificate from the OS trust store — no need to mount a custom CA into the agent pods.

---

## 🧩 Manual Setup for `strict` TLS Mode

Use the steps below if you want maximum control and prefer `agent-tls-mode: strict`.

---

## 🧩 Step 1: Extract the Rancher Server's CA

On any Linux machine with OpenSSL:

```bash
openssl s_client -connect rancher.sananetco.com:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM > serverca.crt
```

This command extracts the CA certificate chain used by your Rancher domain and saves it to `serverca.crt`.

---

## 🧩 Step 2: Create a ConfigMap from the CA File

Apply the following command to create a ConfigMap named `rancher-ca` in the `cattle-system` namespace:

```bash
kubectl -n cattle-system create configmap rancher-ca --from-file=serverca=serverca.crt
```

> ⚠️ The key name must be exactly `serverca` — the Rancher agent looks for this file.

---

## 🧩 Step 3: Patch the Rancher Agent Deployment

Edit the deployment for the Rancher cluster agent:

```bash
kubectl -n cattle-system edit deployment cattle-cluster-agent
```

### Add the following to the `spec.template.spec.volumes` section:

```yaml
- name: rancher-ca
  configMap:
    name: rancher-ca
```

### And to the `spec.template.spec.containers[0].volumeMounts` section:

```yaml
- name: rancher-ca
  mountPath: /etc/kubernetes/ssl/certs
  readOnly: true
```

Save and exit.

---

## 🧩 Step 4: Restart and Verify Logs

Once the deployment is updated, the pod will restart automatically. Monitor the logs to confirm that the error is gone:

```bash
kubectl -n cattle-system logs -f deployment/cattle-cluster-agent
```

You should no longer see:

```
unable to read CA file from /etc/kubernetes/ssl/certs/serverca
```

---

## ✅ Next Steps

Once this setup is complete and all agents trust the Rancher server using this CA, the `AgentTlsStrictCheck` condition will become `True`, and you'll be able to safely switch:

```bash
agent-tls-mode: strict
```

from the Rancher UI or via `kubectl`.

---

## 🧠 Tip

If you're using Let's Encrypt, the CA you need is usually the **ISRG Root X1** or **R3** intermediate.

---

