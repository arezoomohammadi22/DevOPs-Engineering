output "namespace" {
  value = kubernetes_namespace.this.metadata[0].name
}

output "deployment_name" {
  value = kubernetes_deployment.nginx.metadata[0].name
}

output "service_name" {
  value = kubernetes_service.nginx.metadata[0].name
}
