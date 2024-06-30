```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-username=arezoomohammadi \
  --docker-password=pass \
  --docker-server=https://index.docker.io/v1/ \
  --docker-email=your-email@example.com
```
