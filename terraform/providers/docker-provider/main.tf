terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "3.6.2"
    }
  }
}

provider "docker" {
}
resource "docker_container" "web" {
  name  = "nginx-demo"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8080
  }
}
