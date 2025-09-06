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

# ------------------ Data Source: read existing Secret ------------------
# این بخش چیزی نمی‌سازد؛ فقط Secret موجود را می‌خواند
data "kubernetes_secret" "db" {
  metadata {
    name      = var.secret_name
    namespace = var.namespace
  }
}

# ------------------ Resource: Deployment (uses the Secret) -------------
resource "kubernetes_deployment" "app" {
  metadata {
    name      = "${var.app_name}-deploy"
    namespace = var.namespace
    labels    = { app = var.app_name }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = var.app_name }
    }

    template {
      metadata {
        labels = { app = var.app_name }
      }

      spec {
        container {
          name  = var.app_name
          image = var.image

          port { container_port = 80 }

          # نمونه: گرفتن مقادیر env از Secret موجود
          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret.db.metadata[0].name
                key  = "username"        # کلید داخل Secret
              }
            }
          }

          env {
            name = "DB_PASS"
            value_from {
              secret_key_ref {
                name = data.kubernetes_secret.db.metadata[0].name
                key  = "password"        # کلید داخل Secret
              }
            }
          }

          # پروب‌ها برای استایل production-ی‌تر
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
        }
      }
    }
  }
}

# ------------------ Resource: Service ----------------------------------
resource "kubernetes_service" "app" {
  metadata {
    name      = "${var.app_name}-svc"
    namespace = var.namespace
    labels    = { app = var.app_name }
  }

  spec {
    selector = { app = var.app_name }

    port {
      port        = var.service_port
      target_port = 80
    }

    type = var.service_type
  }
}
