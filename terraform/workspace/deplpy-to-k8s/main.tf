terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# هر محیط (dev/prod/...) namespace خودش رو داره
resource "kubernetes_namespace" "example" {
  metadata {
    name = "${terraform.workspace}-namespace"
  }
}

# یک Deployment در هر محیط ساخته میشه
resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.example.metadata[0].name
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = 1
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
          image = "nginx:1.25"
          name  = "nginx"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}
