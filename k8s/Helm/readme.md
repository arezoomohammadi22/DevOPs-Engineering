# Helm v3 Crash Course & Command Cheat‑Sheet

A concise, practical guide to get productive with Helm v3—Kubernetes’ package manager. Use it as a learning path + quick reference.

---

## 📦 What is Helm?
Helm is the package manager for Kubernetes. A **chart** packages K8s manifests and default values; installing a chart creates a **release** in your cluster. Helm renders templates with Go templating using `.Values` you provide (via `values.yaml`, `-f`, or `--set`).

---

## ✅ Prerequisites
- A working Kubernetes cluster (minikube, kind, k3s, AKS/EKS/GKE, etc.).  
- `kubectl` configured and talking to your cluster:  
  ```bash
  kubectl get nodes
  ```
- Helm v3 installed. Quick install (Linux/macOS):
  ```bash
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ```
  Windows: install via Chocolatey (`choco install kubernetes-helm`) or Scoop (`scoop install helm`).

> Tip: Keep your kube context separate per env (dev/stage/prod) to avoid surprises.

---

## 🚀 Quick Start (10–15 min)

### 1) Add a repo and explore a chart
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx
helm show values bitnami/nginx | sed -n '1,80p'
```

### 2) Install → Upgrade → Roll back
```bash
kubectl create ns web
helm install demo bitnami/nginx -n web
kubectl get svc -n web
helm upgrade demo bitnami/nginx -n web --set service.type=LoadBalancer
helm history demo -n web
helm rollback demo 1 -n web
helm uninstall demo -n web
```

### 3) Create your own chart
```bash
helm create hello
tree hello
```
Key files:
- `Chart.yaml` – chart metadata
- `values.yaml` – default settings
- `templates/` – Go‑templated K8s manifests
- `templates/_helpers.tpl` – reusable partials
- `templates/NOTES.txt` – post‑install tips shown to users

Render and install:
```bash
helm lint hello
helm template hello                  # render to stdout (no cluster changes)
helm install hello ./hello -n web
helm upgrade hello ./hello -n web --set replicaCount=3 --set image.tag=1.27
```

---

## 🧰 Daily Helm Commands (Reference)
```bash
# Repos & discovery
helm repo add NAME URL
helm repo list
helm repo update
helm search repo KEYWORD
helm show values REPO/CHART
helm show chart REPO/CHART

# Render & lint (safe testing)
helm lint PATH/TO/CHART
helm template PATH/TO/CHART -f values.yaml
helm install --dry-run --debug RELEASE PATH/TO/CHART

# Install / upgrade / rollback
helm install RELEASE REPO/CHART -n NAMESPACE --create-namespace
helm status RELEASE -n NAMESPACE
helm get values RELEASE -n NAMESPACE
helm upgrade RELEASE REPO/CHART -n NAMESPACE -f values.yaml --set key=value
helm history RELEASE -n NAMESPACE
helm rollback RELEASE REVISION -n NAMESPACE
helm uninstall RELEASE -n NAMESPACE

# Packaging
helm package mychart/                 # produces mychart-0.1.0.tgz

# Dependencies
helm dependency update mychart/       # refreshes Chart.lock from Chart.yaml
helm dependency build  mychart/       # vendors charts based on Chart.lock

# OCI registries
helm registry login ghcr.io -u USERNAME
helm push mychart-0.1.0.tgz oci://ghcr.io/USERNAME/charts
helm pull oci://ghcr.io/USERNAME/charts/mychart --version 0.1.0
helm install demo oci://ghcr.io/USERNAME/charts/mychart --version 0.1.0

# Signing & provenance (optional)
helm package --sign --key KEY_ID --keyring ~/.gnupg/pubring.gpg mychart/
helm verify mychart-0.1.0.tgz
```

---

## 🧩 Values & Templating Essentials

### Passing values
- Use files (can repeat; later wins): `-f base.yaml -f dev.yaml`
- Inline overrides: `--set image.tag=1.27,replicaCount=3`
- Inject file content: `--set-file secret.password=./pass.txt`

### Ingress values example
```yaml
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: hello.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: hello-tls
      hosts: [hello.example.com]
```
Guard in template:
```gotemplate
{{- if .Values.ingress.enabled }}
# ingress manifest here…
{{- end }}
```

### Helpful template snippets (`_helpers.tpl`)
```gotemplate
{{- define "hello.labels" -}}
app.kubernetes.io/name: {{ include "hello.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
```
Use in a manifest:
```gotemplate
metadata:
  labels:
{{ include "hello.labels" . | nindent 4 }}
```

Handy functions: `default`, `required`, `toYaml`, `nindent`, `tpl`, `include`, `quote`, `b64enc`.

---

## 🪢 Chart Dependencies (Subcharts)
In `Chart.yaml`:
```yaml
dependencies:
  - name: redis
    version: ">=18.0.0 <19.0.0"
    repository: https://charts.bitnami.com/bitnami
    alias: cache
```
Values for the subchart live under the alias:
```yaml
cache:
  architecture: standalone
  auth:
    enabled: false
```
Commands:
```bash
helm dependency update hello/
helm dependency build  hello/
```

---

## 🧪 Hooks & Tests
- Add a test pod under `templates/tests/` and annotate:
```yaml
metadata:
  annotations:
    "helm.sh/hook": test
```
Run:
```bash
helm test hello -n web
```
Common hooks: `pre-install`, `post-install`, `pre-upgrade`, `post-upgrade`, `pre-delete`, `post-delete`, `test`.  
Control order: `helm.sh/hook-weight`.  
Cleanup: `helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded`.

---

## 🛡️ Production Tips
- Prefer **atomic upgrades** and waits:
  ```bash
  helm upgrade hello ./hello -n web --atomic --wait --timeout 5m
  ```
- Fail early for required inputs:
  ```gotemplate
  {{ required "ingress.host is required" .Values.ingress.host }}
  ```
- Keep templates small; push logic into `_helpers.tpl`.
- Use **values layering** per env (`values-dev.yaml`, `values-prod.yaml`).
- Pin dependency versions; update deliberately.
- Consider **helm-diff** before upgrades:
  ```bash
  helm plugin install https://github.com/databus23/helm-diff
  helm diff upgrade hello ./hello -n web -f values.yaml
  ```

---

## 🧯 Troubleshooting Flow
1. **Render locally**: `helm template` (catches logic errors fast).  
2. **Lint**: `helm lint`.  
3. **Dry‑run to cluster**: `helm install --dry-run --debug`.  
4. **If install fails**: check `kubectl describe` pods/events, CRDs present, RBAC, required values.  
5. **Roll back** quickly: `helm rollback RELEASE REVISION`.  

---

## 📚 Glossary
- **Chart**: A Helm package (templates + defaults).  
- **Release**: A deployed instance of a chart in a cluster.  
- **Values**: Configuration inputs used to render templates.  
- **Subchart**: A chart used as a dependency of another chart.  


Happy Helming! 🛳️
