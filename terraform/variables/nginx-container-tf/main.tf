terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# ایمیج Nginx
resource "docker_image" "nginx" {
  name = var.nginx_image
}

# چند کانتینر بر اساس تعداد
resource "docker_container" "nginx_containers" {
  count = var.container_count

  name  = "nginx_${count.index + 1}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.http_port_start + count.index
  }
}
