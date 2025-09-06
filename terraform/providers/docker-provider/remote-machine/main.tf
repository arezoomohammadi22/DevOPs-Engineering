terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Docker provider over SSH
provider "docker" {
  host = "ssh://root@10.211.55.50"
}

resource "docker_image" "nginx" {
  name = "docker.arvancloud.ir/nginx:alpine"
}

resource "docker_container" "nginx" {
  name  = "nginx-remote"
  image = docker_image.nginx.image_id
  ports {
    internal = 80
    external = 8088
  }
}
