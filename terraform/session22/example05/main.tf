# Define the Docker provider
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.13.0"
    }
  }
}

provider "docker" {
  # No additional configuration is needed if Docker is running locally
}

# Create a Docker network
resource "docker_network" "example_network" {
  name = "example_network"
}

# Pull the Nginx Docker image
resource "docker_image" "nginx" {
  name = "nginx:latest"
  keep_locally = false
}

# Run a Docker container using the Nginx image
resource "docker_container" "nginx_container" {
  name  = "example_nginx"
  image = docker_image.nginx.latest
  networks_advanced {
    name = docker_network.example_network.name
  }
  ports {
    internal = 80
    external = 8080
  }
}
