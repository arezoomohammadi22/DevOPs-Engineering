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

## Explanation of the Command:

--non-interactive: Run in non-interactive mode.
--url "https://gitlab.sananetco.com/": URL of your GitLab instance.
--registration-token "YOUR_REGISTRATION_TOKEN": The registration token provided by GitLab for your runner.
--executor "docker": Use Docker as the executor.
--docker-image arezoomohammadi/runner:v1: The Docker image to use for the runner.
--description "runner with docker executer": A description for your runner.
--tag-list "shared": Tags for your runner.
--run-untagged="true": Allow the runner to pick up untagged jobs.
--locked="false": Allow the runner to be unlocked.
--access-level="not_protected": Set the access level to not protected.
--docker-volumes "/certs/client": Volume mount for certificates.
--docker-pull-policy "if-not-present": Pull policy for Docker images.
--docker-volumes /var/run/docker.sock:/var/run/docker.sock: Mount the Docker socket to allow Docker-in-Docker.
