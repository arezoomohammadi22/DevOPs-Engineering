terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

module "nginx1" {
  source         = "./modules/nginx_container"
  container_name = "nginx-app1"
  external_port  = 8080
}

module "nginx2" {
  source         = "./modules/nginx_container"
  container_name = "nginx-app2"
  external_port  = 8081
}
