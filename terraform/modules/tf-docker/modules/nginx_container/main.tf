resource "docker_image" "nginx" {
  name = var.image
}

resource "docker_container" "nginx" {
  name  = var.container_name
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.external_port
  }
}
