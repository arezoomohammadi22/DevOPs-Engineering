# Define the Kubernetes provider
provider "kubernetes" {
  config_path = "~/.kube/config"  # Adjust this path if your kubeconfig is located elsewhere
}

# Create a Kubernetes pod
resource "kubernetes_pod" "example_pod" {
  metadata {
    name = "example-pod"
    labels = {
      app = "nginx"
    }
  }

  spec {
    container {
      name  = "nginx"
      image = "docker.arvancloud.ir/nginx:1.21.1"
      port {
        container_port = 80
      }
    }
  }
}
