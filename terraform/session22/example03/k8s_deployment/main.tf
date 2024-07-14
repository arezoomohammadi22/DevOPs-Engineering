# Define the Kubernetes provider
provider "kubernetes" {
  config_path = "~/.kube/config"  # Adjust this path if your kubeconfig is located elsewhere
}

# Create a Kubernetes deployment
resource "kubernetes_deployment" "nginx_deployment" {
  metadata {
    name = "nginx-deployment"
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = 3

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
          image = "nginx:1.21.1"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Create a Kubernetes service to expose the deployment
resource "kubernetes_service" "nginx_service" {
  metadata {
    name = "nginx-service"
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
