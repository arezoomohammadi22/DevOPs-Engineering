# Define the Kubernetes provider
provider "kubernetes" {
  config_path = "~/.kube/config"  # Adjust this path if your kubeconfig is located elsewhere
}

# Define a Kubernetes namespace for Redis
resource "kubernetes_namespace" "redis" {
  metadata {
    name = "redis"
  }
}

# Define a headless service for Redis StatefulSet
resource "kubernetes_service" "redis_headless" {
  metadata {
    name      = "redis-headless"
    namespace = kubernetes_namespace.redis.metadata[0].name
    labels = {
      app = "redis"
    }
  }

  spec {
    cluster_ip = "None"
    selector = {
      app = "redis"
    }
    port {
      name       = "redis"
      port       = 6379
      target_port = 6379
    }
  }
}

# Define a StatefulSet for Redis
resource "kubernetes_stateful_set" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.redis.metadata[0].name
    labels = {
      app = "redis"
    }
  }

  spec {
    service_name = kubernetes_service.redis_headless.metadata[0].name
    replicas     = 3

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:6.2.5"

          port {
            container_port = 6379
            name           = "redis"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

# Define a ClusterIP service for Redis clients to connect to
resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.redis.metadata[0].name
    labels = {
      app = "redis"
    }
  }

  spec {
    selector = {
      app = "redis"
    }
    port {
      name       = "redis"
      port       = 6379
      target_port = 6379
    }

    type = "ClusterIP"
  }
}
