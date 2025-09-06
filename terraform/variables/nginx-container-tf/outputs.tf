output "nginx_containers" {
  value = [for c in docker_container.nginx_containers : "${c.name} -> http://localhost:${c.ports[0].external}"]
}
