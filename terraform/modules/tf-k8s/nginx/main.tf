resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = var.namespace
    labels    = { app = "nginx" }
  }

  spec {
    replicas = var.replicas

    selector { match_labels = { app = "nginx" } }

    template {
      metadata { labels = { app = "nginx" } }

      spec {
        container {
          name  = "nginx"
          image = var.image
          port  { container_port = 80 }
        }
      }
    }
  }
}
