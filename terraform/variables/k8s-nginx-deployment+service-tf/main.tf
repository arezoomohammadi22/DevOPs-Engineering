terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Namespace
resource "kubernetes_namespace" "example" {
  metadata {
    name = var.namespace
  }
}

# Deployment
resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.example.metadata[0].name
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = var.nginx_image

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.example.metadata[0].name
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "NodePort"
  }
}
