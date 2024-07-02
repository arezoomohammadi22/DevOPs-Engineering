```bash
frontend/
├── Dockerfile
├── deploy/
│   ├── Chart.yaml
│   ├── charts/
│   ├── templates/
│   │   ├── NOTES.txt
│   │   ├── _helpers.tpl
│   │   ├── deployment.yaml
│   │   ├── hpa.yaml
│   │   ├── ingress.yaml
│   │   ├── service.yaml
│   │   ├── serviceaccount.yaml
│   │   └── tests/
│   │       └── test-connection.yaml
│   └── values.yaml
├── package.json
├── public/
│   └── index.html
└── src/
    ├── App.css
    ├── App.js
    ├── index.css
    └── index.js
```
```bash
kubectl create secret docker-registry my-registry-secret \
        --docker-server=registry.sananetco.com \
        --docker-username=admin \
        --docker-password=123@qwe \
        --docker-email=admin@sananetco.com \

```
