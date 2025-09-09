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

# Namespace per workspace
resource "kubernetes_namespace" "this" {
  metadata {
    name = "${terraform.workspace}-namespace"
  }
}

# Deployment using workspace-specific variables
resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-${terraform.workspace}"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = var.replica_count[terraform.workspace]

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
          image = var.image_tag[terraform.workspace]
          name  = "nginx"
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
    name      = "nginx-service-${terraform.workspace}"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}
