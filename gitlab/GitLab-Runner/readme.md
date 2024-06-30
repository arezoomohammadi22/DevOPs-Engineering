```bash
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.sananetco.com/" \
  --registration-token "YOUR_REGISTRATION_TOKEN" \
  --executor "docker" \
  --docker-image arezoomohammadi/runner:v1 \
  --description "runner with docker executer" \
  --tag-list "shared" \
  --run-untagged="true" \
  --locked="false" \
  --access-level="not_protected" \
  --docker-volumes "/certs/client" \
  --docker-pull-policy "if-not-present" \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock
```
