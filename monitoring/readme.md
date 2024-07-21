```sh
container_memory_usage_bytes{name="gitlab-runner"} / (1024 * 1024 * 1024)
rate(container_cpu_usage_seconds_total{name="nginx"}[5m])
sum(rate(container_cpu_usage_seconds_total{name="nginx"}[5m])) * 100
