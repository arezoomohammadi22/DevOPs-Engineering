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

# ConfigMap for Nginx custom config
resource "kubernetes_config_map" "nginx_cfg" {
  metadata {
    name      = "nginx-conf"
    namespace = kubernetes_namespace.example.metadata[0].name
  }

  data = {
    "default.conf" = <<-CONF
      server {
        listen 80;
        location / {
          return 200 'OK from ${var.namespace}!';
        }
      }
    CONF
  }

  depends_on = [kubernetes_namespace.example]
}

# Deployment with probes & resources
resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.example.metadata[0].name
    labels    = { app = "nginx", tier = "web" }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = "nginx" }
    }

    template {
      metadata {
        labels = { app = "nginx", tier = "web" }
      }

      spec {
        container {
          name  = "nginx"
          image = var.nginx_image

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          volume_mount {
            name       = "nginx-conf"
            mount_path = "/etc/nginx/conf.d"
          }
        }

        volume {
          name = "nginx-conf"
          config_map {
            name = kubernetes_config_map.nginx_cfg.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.example, kubernetes_config_map.nginx_cfg]
}

# Service
resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.example.metadata[0].name
  }

  spec {
    selector = { app = "nginx" }

    port {
      port        = var.service_port
      target_port = 80
    }

    type = var.service_type
  }

  depends_on = [kubernetes_namespace.example]
}

# Ingress (optional, requires ingress controller + cert-manager)
resource "kubernetes_ingress_v1" "nginx" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "nginx-ing"
    namespace = kubernetes_namespace.example.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"    = var.ingress_class
      "cert-manager.io/cluster-issuer" = var.cluster_issuer
    }
  }

  spec {
    tls {
      hosts       = [var.domain]
      secret_name = "nginx-tls"
    }
    rule {
      host = var.domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx.metadata[0].name
              port { number = var.service_port }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.example, kubernetes_service.nginx]
}
